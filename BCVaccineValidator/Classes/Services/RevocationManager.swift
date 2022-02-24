//
//  RevocationManager.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 15/02/22.
//

import Foundation
import CoreMedia

internal final class RevocationManager: DirectoryManager {
    static let shared = RevocationManager()
    
    private typealias Issuer = String
    private typealias IssuerFilePathSafeName = String
    private typealias KeyId = String
    private typealias RevocationDataSet = SynchronizedDictionary<IssuerFilePathSafeName, SynchronizedDictionary<KeyId, RevocationData>>
    
    private static let crlFileNameFormat = "%@.json" // NO I18N
    private static let crlDirectoryName = "crl" // NO I18N
    private static let vaxValidatorCrlDataUDKeyFormat = "vaxValidatorCrlData_%@_%@_savedAt" // NO I18N
    
    private lazy var crlDirectoryURL = documentDirectory().appendingPathComponent(RevocationManager.crlDirectoryName)
    private let fetchingKeyIds = SynchronizedSet<String>()
    private let revocationDataSet = RevocationDataSet()
    private let notFoundEndPoints = SynchronizedDictionary<IssuerFilePathSafeName, SynchronizedDictionary<KeyId, Date>>()
    
    init() {
        seedLocalRevocationData(to: revocationDataSet)
    }
}

// MARK: Functions
internal extension RevocationManager {
    func isPvcRevoked(issuer: String, issueDate: Date, rId: String, kId: String) -> Bool {
        downloadAndCacheIfNeeded(completion: { })
        // Reject the Health Card if the calculated rid is contained in the CRL's rids array and (if a timestamp suffix is present) the Health Card’s nbf is value is before the timestamp.
        guard let revocationData = revocationDataSet[getFilePathSafeName(issuer: issuer)]?[kId],
              revocationData.rids.contains(rId) else {
            return false
        }
        if let associatedDate = revocationData.revocationExpiry[rId] {
            return issueDate < associatedDate
        } else {
            return true
        }
    }
    
    func downloadAndCacheIfNeeded(completion: @escaping () -> Void) {
        // Get list of issuers
        if let issuers = IssuerManager.shared.getIssuers() {
            let dispatchGroup = DispatchGroup()
            issuers.participatingIssuers.forEach { issuer in
                dispatchGroup.enter()
                self.downloadAndCacheCardRevocationListIfNeeded(issuer: issuer.iss, completion: { isSuccess in
                    isSuccess ? Logger.logInfo("downloadAndCacheCardRevocationListIfNeeded: iss: \(issuer.iss); Completion") : // NO I18N
                    Logger.logFailure("downloadAndCacheCardRevocationListIfNeeded: iss: \(issuer.iss); failed") // NO I18N
                    dispatchGroup.leave()
                })
            }
            dispatchGroup.notify(queue: .main) {
                completion()
            }
        } else {
            // It is highly unlikely that result is nil.
            Logger.logFailure("Critical Error: No issuers found") // NO I18N
            completion()
        }
    }
    
    // Example -> issuer: https://pvc.service.yukon.ca/issuer"
    func downloadAndCacheCardRevocationListIfNeeded(issuer: String, completion: @escaping (_ success: Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var isSuccess = true
        dispatchGroup.enter()
        KeyManager.shared.fetchLocalKeys(issuer: issuer, completion: { [weak self] result in
            dispatchGroup.leave()
            guard let self = self, let keysResult = result else { return }
            self.removeUnnecessaryCache(issuer: issuer, keys: keysResult.keys)
            for key in keysResult.keys {
                dispatchGroup.enter()
                self.downloadAndCacheCardRevocationListIfNeeded(issuer: issuer, key: key, completion: {
                    if let error = $0 {
                        isSuccess = false
                        Logger.logFailure("Completion: error: \(error); issuer: \(issuer); keyId: \(key.kid);") // NO I18N
                    } else {
                        Logger.logInfo("Completion: issuer: \(issuer); keyId: \(key.kid);") // NO I18N
                    }
                    dispatchGroup.leave()
                })
            }
        })
        dispatchGroup.notify(queue: .main) {
            completion(isSuccess)
        }
    }
    
    func downloadAndCacheCardRevocationListIfNeeded(issuer: String, key: Key, completion: @escaping (Error?) -> Void) {
        guard !key.kid.isEmpty, !self.fetchingKeyIds.contains(key.kid) else {
            return completion(nil)
        }
        let filePathSafeName = self.getFilePathSafeName(issuer: issuer)
        if let notFoundDate = self.notFoundEndPoints[filePathSafeName]?[key.kid] {
            // Preventing unnecessary network operation to the endpoint that doesn't exist for a brief period.
            guard Date() >
                    notFoundDate.addingTimeInterval(TimeInterval(RulesManager.shared.getRevocationsCacheExpiryIntervalInMinutes() * 60)) else {
                return completion(nil)
            }
        }
        if let ctr = key.ctr?.rawValue {
            guard ctr != revocationDataSet[filePathSafeName]?[key.kid]?.ctr else {
                // Different ctr (Counter) indicates that we need to fetch in the new list.
                return completion(nil)
            }
        } else {
            if let localDataSavedAt = UserDefaults.standard.object(forKey: getCrlDataSavedAtUDKey(issuer: issuer, keyId: key.kid)) as? Date {
                guard Date() >
                        localDataSavedAt.addingTimeInterval(TimeInterval(RulesManager.shared.getRevocationsCacheExpiryIntervalInMinutes() * 60)) else {
                    return completion(nil)
                }
            }
        }
        self.fetchingKeyIds.insert(key.kid)
        let network = NetworkService()
        network.getCRL(keyId: key.kid, issuer: issuer, completion: { [weak self] (result, error, statusCode) in
            if let self = self {
                if let crlData = result {
                    self.update(dataset: self.revocationDataSet, data: crlData, issuerFilePathSafeName: filePathSafeName)
                    _ = self.store(crlData: crlData, issuer: issuer, keyId: key.kid)
                }
                if statusCode == 404 { // Not found
                    if let existingData = self.notFoundEndPoints[filePathSafeName] {
                        existingData[key.kid] = Date()
                        self.notFoundEndPoints[filePathSafeName] = existingData
                    } else {
                        let sDict = SynchronizedDictionary<KeyId, Date>()
                        sDict[key.kid] = Date()
                        self.notFoundEndPoints[filePathSafeName] = sDict
                    }
                } else {
                    self.notFoundEndPoints[filePathSafeName]?[key.kid] = nil
                }
                self.fetchingKeyIds.remove(key.kid)
            }
            completion(error)
        })
    }
}

// MARK: Helper Functions
private extension RevocationManager {
    private func seedLocalRevocationData(to revocationDataSet: RevocationDataSet) {
        guard directoryExists(path: crlDirectoryURL) else { return }
        let resourceKeys: [URLResourceKey] = [.parentDirectoryURLKey, .isDirectoryKey]
        let dirEnumerator = FileManager.default.enumerator(at: crlDirectoryURL, includingPropertiesForKeys: resourceKeys, options: [], errorHandler: { url, error in
            Logger.logFailure("error: \(error); url: \(url);") // NO I18N
            return true
        })
        while let itemUrl = dirEnumerator?.nextObject() as? URL {
            do {
                let resourceValues = try itemUrl.resourceValues(forKeys: Set(resourceKeys))
                if let isDirectory = resourceValues.isDirectory, !isDirectory,
                   let parentDirectory = resourceValues.parentDirectory,
                   !parentDirectory.lastPathComponent.isEmpty {
                    do {
                        let data = try Data(contentsOf: itemUrl)
                        let crlResponse = try JSONDecoder().decode(CardRevocationListResponse.self, from: data)
                        update(dataset: revocationDataSet, data: crlResponse, issuerFilePathSafeName: parentDirectory.lastPathComponent)
                    } catch {
                        Logger.logFailure("Exeption while reading/decoding. error: \(error)") // NO I18N
                    }
                }
            } catch {
                Logger.logFailure("resourceValues exception: error: \(error)") // NO I18N
            }
        }
    }
        
    private func update(dataset: RevocationDataSet, data: CardRevocationListResponse, issuerFilePathSafeName: String) {
        var revocationsExpiry = [RevocationData.RevocationId: Date]()
        var rids = Set<String>()
        // Example 'rids' -> ["AQPCj4wwk6Mt", "lHKzqFUMjhs.1636977600"]
        // 1636977600 -> Seconds
        data.rids.forEach {
            let items = $0.components(separatedBy: ".") // NO I18N
            if items.count > 1, let timeInterval = TimeInterval(items[1]) {
                revocationsExpiry[items[0]] = Date(timeIntervalSince1970: timeInterval)
            }
            rids.insert(items[0])
        }
        let revocationData = RevocationData(keyId: data.kid, rids: rids, ctr: data.ctr?.rawValue, revocationExpiry: revocationsExpiry)
        if let existingData = dataset[issuerFilePathSafeName] {
            existingData[data.kid] = revocationData
            dataset[issuerFilePathSafeName] = existingData
        } else {
            let sDict = SynchronizedDictionary<KeyId, RevocationData>()
            sDict[data.kid] = revocationData
            dataset[issuerFilePathSafeName] = sDict
        }
    }
    
    func store(crlData: CardRevocationListResponse, issuer: String, keyId: String) -> Bool {
        guard ensureCrlDir(issuer: issuer) else { return false }
        let filePath = getFilePath(issuer: issuer, keyId: keyId)
        do {
            // Convert struct to data
            let data = try JSONEncoder().encode(crlData)
            try data.write(to: filePath)
            UserDefaults.standard.set(Date(), forKey: getCrlDataSavedAtUDKey(issuer: issuer, keyId: keyId))
            return true
        } catch {
            Logger.logFailure("Caching crlData failed. Error: \(error.localizedDescription); issuer: \(issuer); keyId: \(keyId)") // NO I18N
            return false
        }
    }
    
    func ensureCrlDir(issuer: String) -> Bool {
        let issuerDir = getDirectory(for: issuer.removeWellKnownJWKS_URLExtension().lowercased())
        // Create directory for the issuer (if one doesnt exist already)
        createDirectoryIfDoesntExist(path: issuerDir)
        return directoryExists(path: issuerDir)
    }
    
    func getFilePath(issuer: String, keyId: String) -> URL {
        let issuerDir = getDirectory(for: issuer.removeWellKnownJWKS_URLExtension().lowercased())
        return issuerDir.appendingPathComponent(getCrlDataFileName(keyId: keyId))
    }
    
    func getDirectory(for issuer: String) -> URL {
        // for example, it will be a directory named: smarthealthcard.phsa.ca~v1~issuer
        let dirPath = crlDirectoryURL.appendingPathComponent(getFilePathSafeName(issuer: issuer))
        return dirPath
    }
    
    func getFilePathSafeName(issuer: String) -> String {
        issuer.filePathSafeName()
    }
    
    func getCrlDataFileName(keyId: String) -> String {
        String(format: RevocationManager.crlFileNameFormat, keyId)
    }
    
    func getCrlDataSavedAtUDKey(issuer: String, keyId: String) -> String {
        String(format: RevocationManager.vaxValidatorCrlDataUDKeyFormat, getFilePathSafeName(issuer: issuer), keyId)
    }
    
    func removeUnnecessaryCache(issuer: String, keys: [Key]) {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        let dirUrl = crlDirectoryURL.appendingPathComponent(getFilePathSafeName(issuer: issuer))
        guard directoryExists(path: dirUrl) else { return }
        let dirEnumerator = FileManager.default.enumerator(at: dirUrl, includingPropertiesForKeys: resourceKeys, options: [], errorHandler: { url, error in
            Logger.logFailure("error: \(error); url: \(url);") // NO I18N
            return true
        })
        let validKeyIds = keys.map { $0.kid }
        while let itemUrl = dirEnumerator?.nextObject() as? URL {
            do {
                let resourceValues = try itemUrl.resourceValues(forKeys: Set(resourceKeys))
                if let isDirectory = resourceValues.isDirectory, !isDirectory {
                    if !validKeyIds.contains(where: itemUrl.lastPathComponent.contains) {
                        try FileManager.default.removeItem(at: itemUrl)
                        if let kIds = revocationDataSet[getFilePathSafeName(issuer: issuer)]?.keys {
                            for kId in Array(kIds) {
                                if itemUrl.lastPathComponent.contains(kId) {
                                    revocationDataSet[getFilePathSafeName(issuer: issuer)]?[kId] = nil
                                    break
                                }
                            }
                        }
                    }
                }
            } catch {
                Logger.logFailure("resourceValues / removeItem exception: error: \(error)") // NO I18N
            }
        }
    }
}

// MARK: Private Types
private extension RevocationManager {
    struct RevocationData {
        internal typealias RevocationId = String
        
        let keyId: String
        let rids: Set<RevocationId>
        let ctr: String?
        let revocationExpiry: [RevocationId: Date]
    }
}
