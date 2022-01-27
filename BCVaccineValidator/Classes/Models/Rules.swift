//
//  File.swift
//  
//
//  Created by Amir Shayegh on 2021-10-13.
//

import Foundation
// MARK: - Rules
struct VaccinationRules: Codable {
    let publishDateTime: String
    let ruleSet: [RuleSet]
}

// MARK: - RuleSet
struct RuleSet: Codable {
    let mixTypesAllowed: Bool
    let mixTypesRuRequired, ruRequired: Int
    let intervalRequired: Bool
    let daysSinceLastInterval: Int
    let ruleTarget: String
    let version: String
    let vaccinationRules: [VaccinationRule]
    let exemptions: [Exemption]?
}

// MARK: - VaccinationRule
struct VaccinationRule: Codable {
    let cvxCode: String
    let type, ru: Int
    let minDays: ValueWrapper?
}

// MARK: - Exemption
struct Exemption: Codable {
    let issuer: String
    let codingSystems: [String]
    let codes: [String]
}

enum VaccinationType: Int {
    case NotSet = 0
    case Mrna = 1
    case NRVV = 2
    case WInac = 3
}
