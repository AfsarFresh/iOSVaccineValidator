//
//  ValueWrapper.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 16/12/21.
//

import Foundation

/// For the purpose of encoding and decoding. Prevents JSONDecoder from failing. Solves the problem when an REST API returns different data types for the same key at different endpoints or scenarios.
internal enum ValueWrapper: Codable, CustomStringConvertible {
    case stringValue(String)
    case intValue(Int)
    case doubleValue(Double)
    case boolValue(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .stringValue(value)
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .boolValue(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .intValue(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .doubleValue(value)
            return
        }

        throw DecodingError.typeMismatch(ValueWrapper.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for ValueWrapper"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .stringValue(value):
            try container.encode(value)
        case let .boolValue(value):
            try container.encode(value)
        case let .intValue(value):
            try container.encode(value)
        case let .doubleValue(value):
            try container.encode(value)
        }
    }

    var rawValue: String {
        var result: String
        switch self {
        case let .stringValue(value):
            result = value
        case let .boolValue(value):
            result = String(value)
        case let .intValue(value):
            result = String(value)
        case let .doubleValue(value):
            result = String(value)
        }
        return result
    }

    var intValue: Int? {
        var result: Int?
        switch self {
        case let .stringValue(value):
            result = Int(value)
        case let .intValue(value):
            result = value
        case let .boolValue(value):
            result = value ? 1 : 0
        case let .doubleValue(value):
            result = Int(value)
        }
        return result
    }

    var boolValue: Bool? {
        var result: Bool?
        switch self {
        case let .stringValue(value):
            result = Bool(value)
        case let .boolValue(value):
            result = value
        case let .intValue(value):
            result = Bool(truncating: value as NSNumber)
        case let .doubleValue(value):
            result = Bool(truncating: value as NSNumber)
        }
        return result
    }
    
    // MARK: CustomStringConvertible Conformance
    public var description: String {
        return self.rawValue
    }
}
