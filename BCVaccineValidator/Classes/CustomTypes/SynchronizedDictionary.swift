//
//  SynchronizedDictionary.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 15/02/22.
//

import Foundation

// Based on
// https://basememara.com/creating-thread-safe-arrays-in-swift/
/// A thread-safe dictionary.
internal final class SynchronizedDictionary<Key: Hashable, Value: Any>: CustomStringConvertible {
    // MARK: Private ICons
    private let _cQueue: DispatchQueue = {
        let queueId = String(describing: SynchronizedDictionary.self) + "." + "concurrent" + "." + "\(Date().timeIntervalSince1970)" // NO I18N
        return DispatchQueue(label: queueId, qos: .userInitiated, attributes: .concurrent)
    }()
    
    // MARK: Private IVars
    private var _dict = [Key: Value]()
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
internal extension SynchronizedDictionary {
    /// The first element of the collection.
    var first: (key: Key, value: Value)? {
        var result: (key: Key, value: Value)?
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.first
        }
        return result
    }
    
    /// The number of key-value pairs in the dictionary.
    var count: Int {
        var result = 0
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.count
        }
        return result
    }
    
    /// A Boolean value that indicates whether the dictionary is empty.
    var isEmpty: Bool {
        var result = false
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.isEmpty
        }
        return result
    }
    
    /// A string that represents the contents of the dictionary.
    // CustomStringConvertible Conformance
    var description: String {
        var result = ""
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.description
        }
        return result
    }
    
    var keys: Dictionary<Key, Value>.Keys? {
        var result: Dictionary<Key, Value>.Keys?
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.keys
        }
        return result
    }
    
    var values: Dictionary<Key, Value>.Values? {
        var result: Dictionary<Key, Value>.Values?
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.values
        }
        return result
    }
}

// MARK: - Immutable
internal extension SynchronizedDictionary {
    /// Returns the first element of the sequence that satisfies the given
    /// predicate.
    func first(where predicate: ((key: Key, value: Value)) -> Bool) -> (key: Key, value: Value)? {
        var result: (key: Key, value: Value)?
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.first(where: predicate)
        }
        return result
    }
    
    func filter(_ predicate: ((key: Key, value: Value)) -> Bool) -> [Key: Value] {
        var result: [Key: Value]?
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            result = self._dict.filter(predicate)
        }
        return result ?? [:]
    }
    
    /// Calls the given closure on each element in the sequence in the same order as a for-in loop.
    ///
    /// - Parameter body: A closure that takes an element of the sequence as a parameter.
    func forEach(_ body: ((key: Key, value: Value)) -> Void) {
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            self._dict.forEach(body)
        }
    }
}

// MARK: - Mutable
internal extension SynchronizedDictionary {
    func removeValue(forKey key: Key, completion: ((Value?) -> Void)? = nil) {
        self._cQueue.async(flags: .barrier) { [weak self] in
            guard let self = self, !self._isDeinitialized else {
                DispatchQueue.main.async { completion?(nil) }
                return
            }
            let value = self._dict.removeValue(forKey: key)
            DispatchQueue.main.async { completion?(value) }
        }
    }
    
    /// Removes all key-value pairs from the dictionary.
    func removeAll(keepingCapacity keepCapacity: Bool = false, completion: (() -> Void)? = nil) {
        self._cQueue.async(flags: .barrier) { [weak self] in
            guard let self = self, !self._isDeinitialized else {
                DispatchQueue.main.async { completion?() }
                return
            }
            self._dict.removeAll()
            DispatchQueue.main.async { completion?() }
        }
    }
}

internal extension SynchronizedDictionary {
    /// Accesses the value associated with the given key for reading and writing.
    subscript(key: Key) -> Value? {
        get {
            var result: Value?
            self._cQueue.sync { [weak self] in
                guard let self = self, !self._isDeinitialized else { return }
                result = self._dict[key]
            }
            return result
        }
        set {
            self._cQueue.sync(flags: .barrier) { [weak self] in
                guard let self = self, !self._isDeinitialized else { return }
                self._dict[key] = newValue
            }
        }
    }
    
    func addEntries(from otherDictionary: [Key: Value]) {
        self._cQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            otherDictionary.forEach {
                self._dict[$0.key] = $0.value
            }
        }
    }
}

// MARK: Helper Functions
private extension SynchronizedDictionary {
    func _forEach(_ body: ((key: Key, value: Value)) -> Void) {
        self._cQueue.sync { [weak self] in
            guard let self = self, !self._isDeinitialized else { return }
            self._dict.forEach(body)
        }
    }
}
