//
//  SynchronizedSet.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 15/02/22.
//

import Foundation

// Based on
// https://basememara.com/creating-thread-safe-arrays-in-swift/
/// A thread-safe Set.
internal final class SynchronizedSet<Element: Hashable>: CustomStringConvertible {
    // MARK: Private ICons
    private let _cQueue: DispatchQueue = {
        let queueId = String(describing: SynchronizedSet.self) + "." + "concurrent" + "." + "\(Date().timeIntervalSince1970)" // NO I18N
        return DispatchQueue(label: queueId, qos: .userInitiated, attributes: .concurrent)
    }()
    
    // MARK: Private IVars
    private var _set = Set<Element>()
    private var _isDeinitialized = false
    
    // MARK: Initialization Function
    public init() { }
    
    // MARK: Deinitialization Function
    deinit {
        Logger.logInfo("deinit") // NO I18N
        self._isDeinitialized = true
    }
}

// MARK: - Properties
internal extension SynchronizedSet {
    var count: Int {
        var result = 0
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._set.count
        }
        return result
    }
    
    /// A string that represents the contents of the dictionary.
    // CustomStringConvertible Conformance
    var description: String {
        var result = ""
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._set.description
        }
        return result
    }
}

// MARK: - Immutable
internal extension SynchronizedSet {
    /// Returns a Boolean value that indicates whether the given element exists
    /// in the set.
    func contains(_ member: Element) -> Bool {
        var contains = false
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            contains = self._set.contains(member)
        }
        return contains
    }
}

// MARK: - Mutable
internal extension SynchronizedSet {
    /// Inserts the given element in the set if it is not already present.
    @discardableResult
    func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        var result = (inserted: false, memberAfterInsert: newMember)
        self._cQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._set.insert(newMember)
        }
        return result
    }
    
    /// Removes the specified element from the set.
    @discardableResult
    func remove(_ member: Element) -> Element? {
        var result: Element? = nil
        self._cQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._set.remove(member)
        }
        return result
    }
}
