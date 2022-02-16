//
//  File.swift
//  
//
//  Created by Amir Shayegh on 2021-09-20.
//

import Foundation

struct Constants {
    static let networkTimeout: Double = 5
    static let crlRequestTimeout: Double = 20 // The request may return a large dataset
    
    struct DataExpiery {
        static var defaultIssuersTimeout: Double { // Minutes
            switch BCVaccineValidator.mode {
            case .Prod:
                return 6 * 60 // 6 hours
            case .Test, .Dev:
                return 1
            }
        }
        
        static var detaultRulesTimeout: Double { // Minutes
            switch BCVaccineValidator.mode {
            case .Prod:
                return 6 * 60 // 6 hours
            case .Test, .Dev:
                return 1
            }
        }
        
        static var revocationsExpiryInMinutes: Double {
            switch BCVaccineValidator.mode {
            case .Prod:
                return 6 * 60 // 6 hours
            case .Test, .Dev:
                return 1
            }
        }
    }
    
    struct JWKSPublic {
        static var prodIssuers = "https://pvc.service.yukon.ca/v1/verifier/.well-known/issuers.json"
        static var devIssuers = "https://pvc.service.yukon.ca/test/v1/verifier/.well-known/issuers.json"
        static var testIssuers = "https://pvc.service.yukon.ca/test/v1/verifier/.well-known/issuers.json"
        static var issuersListUrl: String {
            switch BCVaccineValidator.mode {
            case .Prod:
                return prodIssuers
            case .Test:
                return testIssuers
            case .Dev:
                return devIssuers
            }
        }
        static var prodRules = "https://pvc.service.yukon.ca/v1/verifier/.well-known/rules.json"
        static var devRules = "https://ds9mwekyyprcy.cloudfront.net/yk-rules.json"
        static var testRuls = "https://pvc.service.yukon.ca/test/v1/verifier/.well-known/rules.json"
        
        static var rulesURL: String {
            switch BCVaccineValidator.mode {
            case .Prod:
                return prodRules
            case .Dev:
                return devRules
            case .Test:
                return testRuls
            }
        }
        
        static let wellKnownJWKS_URLExtension = ".well-known/jwks.json" // NO I18N
        static let wellKnownCRL_URLExtensionFormat = ".well-known/crl/%@.json" // NO I18N
    }
    
    struct CVX {
        static let janssen = "212"
    }
    
    struct Directories {
        static let caceDirectoryName: String = "VaccineValidatorCache"
        
        struct issuers {
            static var fileName: String {
                switch BCVaccineValidator.mode {
                case .Prod:
                    return "issuers.json"
                case .Test, .Dev:
                    return "issuers-test.json"
                }
            }
            static let directoryName = "issuers"
        }
        
        struct rules {
            static var fileName: String {
                switch BCVaccineValidator.mode {
                case .Prod:
                    return "rules.json"
                case .Test:
                    return "rules-test.json"
                case .Dev:
                    return "rules-dev.json"
                }
            }
            static let directoryName = "rules"
        }
    }
    
    struct UserDefaultKeys {
        static let issuersTimeOutKey = "issuersTimeout"
        static let vaccinationRulesTimeOutKey = "vaccinationRulesTimeout"
    }
}
