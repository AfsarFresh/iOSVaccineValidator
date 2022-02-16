//
//  Logger.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 15/02/22.
//

import Foundation

internal final class Logger {
    // MARK: Internal Static Vars
    internal static var shouldForceLog = false
    internal private(set) static var shouldLog = true
    
    // MARK: Private Static Cons
    private static let dFrmtr: DateFormatter = {
        let fmtr = DateFormatter()
        fmtr.dateFormat = "yyyy-MM-dd HH:mm:ss" // NO I18N
        return fmtr
    }()
        
    private static let sQueue = DispatchQueue(label: "Logger" + "." + "serial", qos: .utility) // NO I18N
    
    // MARK: Static Functions
    public static func logSuccess(_ messages: Any..., fileName: String = #file, function: String = #function, line: Int = #line, shouldLog: Bool = Logger.shouldLog, date: Date = Date()) {
        self.sQueue.async {
            self.log("✅", date: date, messages: messages, fileName: fileName, function: function, line: line, shouldLog: shouldLog) // NO I18N
        }
    }
    
    public static func logFailure(_ messages: Any..., fileName: String = #file, function: String = #function, line: Int = #line, shouldLog: Bool = Logger.shouldLog, date: Date = Date()) {
        self.sQueue.async {
            self.log("❌", date: date, messages: messages, fileName: fileName, function: function, line: line, shouldLog: shouldLog) // NO I18N
        }
    }
    
    public static func logWarning(_ messages: Any..., fileName: String = #file, function: String = #function, line:Int = #line, shouldLog: Bool = Logger.shouldLog, date: Date = Date()) {
        self.sQueue.async {
            self.log("⚠️", date: date, messages: messages, fileName: fileName, function: function, line: line, shouldLog: shouldLog) // NO I18N
        }
    }

    public static func logInfo(_ messages: Any..., fileName: String = #file, function: String = #function, line: Int = #line, shouldLog: Bool = Logger.shouldLog, date: Date = Date()) {
        self.sQueue.async {
            self.log("ℹ️", date: date, messages: messages, fileName: fileName, function: function, line: line, shouldLog: shouldLog) // NO I18N
        }
    }
    
    deinit {
        Logger.logInfo("deinit")
    }
    
    // Blocking Class Initialization by using `private`
    private init() { }
}

// MARK: Helper Functions Extension
private extension Logger {
    private static func log(_ type: String = "🖌", date: Date = Date(), messages: Any..., fileName: String = " ", function: String = #function, line: Int = #line, shouldLog: Bool) { //NO I18N
        
        #if !DEBUG
        
        return
        
        #else
        
        guard (shouldLog || Logger.shouldForceLog) else {
            return
        }
        let fileName = fileName.components(separatedBy: "/").last ?? ""
        
        print("㏒", type, self.dFrmtr.ms_microsecondPrecisionString(from: date), fileName, ":", function, "in line:", line, "-", separator: " ", terminator: " ") //NO I18N
        printArrayOfMessages(messages: messages)

        #endif
    }
    
    private static func printArrayOfMessages(messages: Array<Any>) {
        for message in messages {
            if message is Array<Any> {
                self.printArrayOfMessages(messages: message as! Array)
                continue
            }
            print(message, separator: " ", terminator: " ")
        }
        print("", separator: "", terminator: "\n")
    }
}
