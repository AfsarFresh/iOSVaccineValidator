//
//  CardRevocationListResponse.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 15/02/22.
//

import Foundation

struct CardRevocationListResponse: Codable {
    let kid, method: String
    let ctr: ValueWrapper?
    let rids: [String]
}
