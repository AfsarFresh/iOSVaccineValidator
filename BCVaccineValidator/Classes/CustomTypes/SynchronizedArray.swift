//
//  SynchronizedArray.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 17/02/22.
//

import Foundation

// https://basememara.com/creating-thread-safe-arrays-in-swift/
/// A thread-safe array.
public final class SynchronizedArray<Element>: CustomStringConvertible {
    // MARK: Private IVars
    private let cQueue: DispatchQueue = {
        let queueId = "\(SynchronizedArray.self)" + "." + "concurrent" + "." + "\(Date().timeIntervalSince1970)" // NO I18N
        return DispatchQueue(label: queueId, qos: .userInitiated, attributes: .concurrent) // NO I18N
    }()
    private var array = [Element]()
    private var isDeinitialized = false
    
    // MARK: Initialization Function
    public init() { }
    
    // MARK: Deinitialization Function
    deinit {
        isDeinitialized = true
    }
}

// MARK: - Properties
public extension SynchronizedArray {
    /// The first element of the collection.
    var first: Element? {
        var result: Element?
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.first
        }
        return result
    }
    
    /// The last element of the collection.
    var last: Element? {
        var result: Element?
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.last
        }
        return result
    }
    
    /// The number of elements in the array.
    var count: Int {
        var result = 0
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.count
        }
        return result
    }
    
    /// A Boolean value indicating whether the collection is empty.
    var isEmpty: Bool {
        var result = false
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.isEmpty
        }
        return result
    }
    
    var values: [Element] {
        var result: [Element]?
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array
        }
        return result!
    }
    
    /// A textual representation of the array and its elements.
    // CustomStringConvertible Conformance
    var description: String {
        var result = ""
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.description
        }
        return result
    }
}

// MARK: - Immutable
public extension SynchronizedArray {
    /// Returns the first element of the sequence that satisfies the given predicate or nil if no such element is found.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    /// - Returns: The first match or nil if there was no match.
    func first(where predicate: (Element) -> Bool) -> Element? {
        var result: Element?
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.first(where: predicate)
        }
        return result
    }
    
    /// Returns an array containing, in order, the elements of the sequence that satisfy the given predicate.
    ///
    /// - Parameter isIncluded: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be included in the returned array.
    /// - Returns: An array of the elements that includeElement allowed.
    func filter(_ isIncluded: (Element) -> Bool) -> [Element] {
        var result = [Element]()
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.filter(isIncluded)
        }
        return result
    }
    
    /// Returns the first index in which an element of the collection satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: The index of the first element for which predicate returns true. If no elements in the collection satisfy the given predicate, returns nil.
    func firstIndex(where predicate: (Element) -> Bool) -> Int? {
        var result: Int?
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.firstIndex(where: predicate)
        }
        return result
    }
    
    /// Returns the elements of the collection, sorted using the given predicate as the comparison between elements.
    ///
    /// - Parameter areInIncreasingOrder: A predicate that returns true if its first argument should be ordered before its second argument; otherwise, false.
    /// - Returns: A sorted array of the collection’s elements.
    func sorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        var result = [Element]()
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.sorted(by: areInIncreasingOrder)
        }
        return result
    }
    
    /// Returns an array containing the non-nil results of calling the given transformation with each element of this sequence.
    ///
    /// - Parameter transform: A closure that accepts an element of this sequence as its argument and returns an optional value.
    /// - Returns: An array of the non-nil results of calling transform with each element of the sequence.
    func compactMap<ElementOfResult>(_ transform: (Element) -> ElementOfResult?) -> [ElementOfResult] {
        var result = [ElementOfResult]()
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.compactMap(transform)
        }
        return result
    }
    
    /// Calls the given closure on each element in the sequence in the same order as a for-in loop.
    ///
    /// - Parameter body: A closure that takes an element of the sequence as a parameter.
    func forEach(_ body: (Element) -> Void) {
        self._forEach(body)
    }
    
    /// Returns a Boolean value indicating whether the sequence contains an element that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: true if the sequence contains an element that satisfies predicate; otherwise, false.
    func contains(where predicate: (Element) -> Bool) -> Bool {
        var result = false
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.contains(where: predicate)
        }
        return result
    }
}

// MARK: - Mutable
public extension SynchronizedArray {
    /// Adds a new element at the end of the array.
    ///
    /// - Parameter element: The element to append to the array.
    func append( _ element: Element, completion: (() -> Void)? = nil) {
        self.cQueue.async(flags: .barrier) { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            strongSelf.array.append(element)
            completion?()
        }
    }
    
    /// Adds a new element at the end of the array.
    ///
    /// - Parameter element: The element to append to the array.
    func append( _ elements: [Element]) {
        self.cQueue.async(flags: .barrier) { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            strongSelf.array += elements
        }
    }
    
    /// Inserts a new element at the specified position.
    ///
    /// - Parameters:
    ///   - element: The new element to insert into the array.
    ///   - index: The position at which to insert the new element.
    func insert( _ element: Element, at index: Int) {
        self.cQueue.async(flags: .barrier) { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            strongSelf.array.insert(element, at: index)
        }
    }
    
    /// Removes and returns the element at the specified position.
    ///
    /// - Parameters:
    ///   - index: The position of the element to remove.
    ///   - completion: The handler with the removed element.
    func remove(at index: Int, completion: ((Element) -> Void)? = nil) {
        self.cQueue.async(flags: .barrier) { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            let element = strongSelf.array.remove(at: index)
            completion?(element)
        }
    }
    
    /// Removes and returns the element at the specified position.
    ///
    /// - Parameters:
    ///   - predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    ///   - completion: The handler with the removed element.
    func remove(where predicate: @escaping (Element) -> Bool, completion: ((Element?) -> Void)? = nil) {
        self.cQueue.async(flags: .barrier) { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            guard let index = strongSelf.array.firstIndex(where: predicate) else {
                completion?(nil)
                return
            }
            let element = strongSelf.array.remove(at: index)
            completion?(element)
        }
    }
    
    /// Removes all elements from the array.
    ///
    /// - Parameter completion: The handler with the removed elements.
    func removeAll(completion: (([Element]) -> Void)? = nil) {
        self.cQueue.async(flags: .barrier) { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            let elements = strongSelf.array
            strongSelf.array.removeAll()
            completion?(elements)
        }
    }
}

public extension SynchronizedArray {
    /// Accesses the element at the specified position if it exists.
    ///
    /// - Parameter index: The position of the element to access.
    /// - Returns: optional element if it exists.
    subscript(index: Int) -> Element? {
        get {
            var result: Element?
            self.cQueue.sync { [weak self] in
                guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
                guard strongSelf.array.startIndex..<strongSelf.array.endIndex ~= index else { return }
                result = strongSelf.array[index]
            }
            return result
        }
        set {
            guard let newValue = newValue else { return }
            self.cQueue.async(flags: .barrier) { [weak self] in
                guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
                strongSelf.array[index] = newValue
            }
        }
    }
}


// MARK: - Equatable
public extension SynchronizedArray where Element: Equatable {
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    ///
    /// - Parameter element: The element to find in the sequence.
    /// - Returns: true if the element was found in the sequence; otherwise, false.
    func contains(_ element: Element) -> Bool {
        var result = false
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            result = strongSelf.array.contains(element)
        }
        return result
    }
}

// MARK: - Infix operators
public extension SynchronizedArray {
    
    static func +=(left: inout SynchronizedArray, right: Element) {
        left.append(right)
    }
    
    static func +=(left: inout SynchronizedArray, right: [Element]) {
        left.append(right)
    }
}

// MARK: Helper Functions
private extension SynchronizedArray {
    func _forEach(_ body: (Element) -> Void) {
        self.cQueue.sync { [weak self] in
            guard let strongSelf = self, !strongSelf.isDeinitialized else { return }
            strongSelf.array.forEach(body)
        }
    }
}
