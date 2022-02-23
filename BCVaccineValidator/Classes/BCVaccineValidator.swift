import Foundation

public class BCVaccineValidator {
    public enum Config {
        case Prod
        case Test
        case Dev
    }
    static var mode: Config = .Prod
    static var enableRemoteRules = true
    public static var shouldUpdateWhenOnline = false
    public static let shared = BCVaccineValidator()
    
    static let resourceBundle: Bundle = {
        let myBundle = Bundle(for: BCVaccineValidator.self)

        guard let resourceBundleURL = myBundle.url(
            forResource: "BCVaccineValidator", withExtension: "bundle")
            else { fatalError("MySDK.bundle not found!") }

        guard let resourceBundle = Bundle(url: resourceBundleURL)
            else { fatalError("Cannot access MySDK.bundle!") }

        return resourceBundle
    }()
    
    func initData() {
#if DEBUG
        print("Initialized BCVaccineValidator in \(BCVaccineValidator.mode)")
        print("Enable Remote rules: \(BCVaccineValidator.enableRemoteRules)")
#endif
        loadData()
        // Revocations were added at a later point in time. The below invocation ensures that we fetch in the CRL when we have unexpired cache of public keys.
        RevocationManager.shared.downloadAndCacheIfNeeded(completion: {
            Logger.logInfo("RevocationManager: downloadAndCacheIfNeeded: completion") // NO I18N
        })
        if BCVaccineValidator.enableRemoteRules {
            self.setupReachabilityListener()
            self.setupUpdateListener()
        }
#if DEBUG
        print("\n\nBundled Files: \n")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: BCVaccineValidator.resourceBundle.bundlePath){
            for file in files {
                Logger.logInfo("file: \(file)") // NO I18N
            }
        }
        print("\n\n")
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        print("\(documentsDirectory)\n\n")
        print("\n\n")
#endif
    }
    
    private func loadData() {
        let getIssuersAndRules = {
            _ = RulesManager.shared.getRules()
            _ = IssuerManager.shared.getIssuers()
        }
        
        if BCVaccineValidator.enableRemoteRules {
            if let _ = RulesManager.shared.fetchLocalRules(),
               let rules = RulesManager.shared.getRulesFor(iss: Constants.JWKSPublic.issuer, shouldFallbackToHostForGlobalIssuer: false),
               rules.cache != nil {
                // Locally saved 'cache' object is present.
                getIssuersAndRules()
            } else {
                getIssuersAndRules() // This ensures we seed necessary data irrespective of 'downloadAndUpdateRules' invocations' result.
                // 'cache' object is not available.
                // 'cache' object was added at a later point in time. The below request ensures we fetch it.
                RulesManager.shared.downloadAndUpdateRules(completion: { _ in
                    if let issuers = IssuerManager.shared.getIssuers() {
                        // This ensures we update the issuers' cache expiry interval from backend
                        IssuerManager.shared.updatedIssuers(issuers: issuers, expiresInMinutes: RulesManager.shared.getIssuersCacheExpiryIntervalInMinutes())
                    }
                    // This ensures we update the revocations' based on the cache expiry interval from backend
                    RevocationManager.shared.downloadAndCacheIfNeeded {
                        Logger.logInfo("RevocationManager downloadAndCacheIfNeeded completion") // NO I18N
                    }
                })
            }
        } else {
            getIssuersAndRules()
        }
    }
    
    public func setup(mode: Config,
                      remoteRules: Bool? = true,
                      prodIssuers: String? = nil,
                      devIssuers: String? = nil,
                      testIssuers: String? = nil,
                      prodRules: String? = nil,
                      devRules: String? = nil,
                      testRuls: String? = nil
                      
    ) {
        if let prodIssuers = prodIssuers {
            Constants.JWKSPublic.prodIssuers = prodIssuers
        }
        if let  devIssuers = devIssuers {
            Constants.JWKSPublic.devIssuers = devIssuers
        }
        if let  testIssuers = testIssuers {
            Constants.JWKSPublic.testIssuers = testIssuers
        }
        if let prodRules = prodRules {
            Constants.JWKSPublic.prodRules = prodRules
        }
        if let devRules = devRules {
            Constants.JWKSPublic.devRules = devRules
        }
        if let testRuls = testRuls {
            Constants.JWKSPublic.testRuls = testRuls
        }
        BCVaccineValidator.enableRemoteRules = remoteRules ?? true
        BCVaccineValidator.mode = mode
        initData()
    }
    
    
    
    private func setupUpdateListener() {
        // When issuers list is updated, re-download keys for issuers
        Notification.Name.issuersUpdated.onPost(object: nil, queue: .main) { _ in
            if let issuers = IssuerManager.shared.getIssuers() {
                let issuerURLs = issuers.participatingIssuers.map({ $0.iss })
                KeyManager.shared.downloadKeys(forIssuers: issuerURLs, completion: {
                    Logger.logInfo("KeyManager: downloadKeys: completion") // NO I18N
                    RevocationManager.shared.downloadAndCacheIfNeeded(completion: {
                        Logger.logInfo("RevocationManager: downloadAndCacheIfNeeded: completion") // NO I18N
                    })
                })
            }
        }
    }
    
    /// When network status changes to online,
    /// and if a network call had failed and set shouldUpdateWhenOnline to true,
    /// re-fetch issuers.
    private func setupReachabilityListener() {
        Notification.Name.isReachable.onPost(object: nil, queue: .main) { _ in
            if BCVaccineValidator.shouldUpdateWhenOnline {
                RulesManager.shared.downloadAndUpdateRules(completion: { _ in
                    Logger.logInfo("RulesManager downloadAndUpdateRules completion") // NO I18N
                    IssuerManager.shared.updateIssuers()
                    RevocationManager.shared.downloadAndCacheIfNeeded {
                        Logger.logInfo("RevocationManager downloadAndCacheIfNeeded completion") // NO I18N
                    }
                })
            }
        }
    }
    
    public func validate(code: String, completion: @escaping (CodeValidationResult)->Void) {
        CodeValidationService.shared.validate(code: code.lowercased(), completion: completion)
    }
}
