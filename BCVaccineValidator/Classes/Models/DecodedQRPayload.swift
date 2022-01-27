//
//  DecodedQRCodeModel.swift
//  VaccineCard
//
//  Created by Amir Shayegh on 2021-08-29.
//

import Foundation

// MARK: - DecodedQRPayload
public struct DecodedQRPayload: Codable {
    let iss: String
    let nbf: Double
    let vc: Vc
    /// Expiration date in seconds from 1970-01-01T00:00:00Z UTC, as specified by RFC 7519
    let exp: Double?
}

// MARK: - Vc
public struct Vc: Codable {
    let type: [String]
    let credentialSubject: CredentialSubject
}

// MARK: - CredentialSubject
public struct CredentialSubject: Codable {
    let fhirVersion: String
    let fhirBundle: FhirBundle
}

// MARK: - FhirBundle
public struct FhirBundle: Codable {
    let resourceType, type: String
    let entry: [Entry]
}

// MARK: - Entry
public struct Entry: Codable {
    let fullURL: String
    let resource: Resource
    
    enum CodingKeys: String, CodingKey {
        case fullURL = "fullUrl"
        case resource
    }
}

// MARK: - Resource
public struct Resource: Codable {
    let resourceType: String
    let name: [Name]?
    let birthDate, status: String?
    let vaccineCode: VaccineCode?
    var code: VaccineCode?
    let patient: Patient?
    let occurrenceDateTime: String?
    let performer: [Performer]?
    let lotNumber: String?
    let meta: Meta?
    let onsetDateTime: String?
    let abatementDateTime: String?
}

// MARK: - Meta
public struct Meta: Codable {
    let security: [Security]?
}

// MARK: - Security
public struct Security: Codable {
    let system: String?
    let code: String?
}

// MARK: - Name
public struct Name: Codable {
    let family: String?
    let given: [String]?
}

// MARK: - Patient
public struct Patient: Codable {
    let reference: String
}

// MARK: - Performer
public struct Performer: Codable {
    let actor: Actor?
}

// MARK: - Actor
public struct Actor: Codable {
    let display: String?
}

// MARK: - VaccineCode
public struct VaccineCode: Codable {
    let coding: [Coding]
}

// MARK: - Coding
public struct Coding: Codable {
    let system: String?
    let code: String?
}


public extension DecodedQRPayload {
    var fhirBundle: FhirBundle {
        return vc.credentialSubject.fhirBundle
    }
    
    func fhirBundleHash() -> String? {
        return fhirBundle.toString()?.md5Base64()
    }
    
    func getName() -> String {
        guard let first = self.vc.credentialSubject.fhirBundle.entry.first,
              let nameModel = first.resource.name?.first else {
                  return ""
              }
        
        var fullName = ""
        let familyName = nameModel.family ?? ""
        nameModel.given?.forEach { name in
            fullName += fullName == "" ? "\(name)" : " \(name)"
        }
        fullName = "\(fullName) \(familyName)"
        return fullName
    }
    
    func getBirthDate() -> String? {
        guard let first = self.vc.credentialSubject.fhirBundle.entry.first,
              let birthDate = first.resource.birthDate else {
                  return nil
              }
        return birthDate
    }
    
    func vaxes() -> [Resource] {
        return self.vc.credentialSubject.fhirBundle.entry
            .compactMap({$0.resource}).filter({$0.resourceType.lowercased() == "Immunization".lowercased()})
    }
    
    internal func isExempt(rulesSet: RuleSet) -> Bool {
        let conditionalEntries = self.vc.credentialSubject.fhirBundle.entry.filter {
            $0.resource.resourceType == "Condition"
        }
        let yukonApprovedConditionalEntries = conditionalEntries.filter { condition in
            guard let exemption = rulesSet.exemptions?.first(where: {
                $0.issuer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                    iss.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }) else {
                return false
            }
            let exemptionCodingSystems = exemption.codingSystems.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            let qrCodingSystems = condition.resource.code?.coding.compactMap {
                $0.system?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            } ?? []
            
            let exemptionCodes = exemption.codes.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            let qrExemptionCodes = condition.resource.code?.coding.compactMap {
                $0.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            } ?? []
            
            return exemptionCodingSystems.contains(where: qrCodingSystems.contains) &&
                exemptionCodes.contains(where: qrExemptionCodes.contains)
        }
        let currentDate = Date()
        return yukonApprovedConditionalEntries.contains { entry in
            let onsetDate = entry.resource.onsetDateTime?.vaxDate() ?? currentDate
            let abatementDate = entry.resource.abatementDateTime?.vaxDate() ?? currentDate
            return currentDate >= onsetDate && currentDate <= abatementDate
        }
    }
    
    func isExpired() -> Bool {
        guard let expSecs = exp else {
            return false
        }
        let expDate = Date(timeIntervalSince1970: TimeInterval(expSecs))
        return expDate < Date()
    }
}
