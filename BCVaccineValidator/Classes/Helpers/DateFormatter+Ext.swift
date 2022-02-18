//
//  DateFormatter+Ext.swift
//  BCVaccineValidator
//
//  Created by Mohamed Afsar on 15/02/22.
//

import Foundation

internal extension DateFormatter {
    // https://stackoverflow.com/a/43130186
    func ms_microsecondPrecisionString(from date: Date, withFormat frmt: String = "yyyy-MM-dd HH:mm:ss") -> String {

        if self.dateFormat != frmt {
            self.dateFormat = frmt
        }
        let components = calendar.dateComponents(Set([Calendar.Component.nanosecond]), from: date)
        
        let nanosecondsInMicrosecond = Double(1000)
        let microseconds = lrint(Double(components.nanosecond!) / nanosecondsInMicrosecond)
        
        // Subtract nanoseconds from date to ensure string(from: Date) doesn't attempt faulty rounding.
        let updatedDate = calendar.date(byAdding: .nanosecond, value: -(components.nanosecond!), to: date)!
        let dateTimeString = self.string(from: updatedDate)
        
        let string = String(format: "%@.%06ld",
                            dateTimeString,
                            microseconds)
        
        return string
    }
    
    func ms_microsecondPrecisionDate(from string: String) -> Date? {
        
        let microsecondsPrefix = "."
        self.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        guard let microsecondsPrefixRange = string.range(of: microsecondsPrefix) else { return nil }
        let microsecondsWithTimeZoneString = String(string.suffix(from: microsecondsPrefixRange.upperBound))
        
        let nonDigitsCharacterSet = CharacterSet.decimalDigits.inverted
        guard let timeZoneRangePrefixRange = microsecondsWithTimeZoneString.rangeOfCharacter(from: nonDigitsCharacterSet) else { return nil }
        
        let microsecondsString = String(microsecondsWithTimeZoneString.prefix(upTo: timeZoneRangePrefixRange.lowerBound))
        guard let microsecondsCount = Double(microsecondsString) else { return nil }
        
        let dateStringExludingMicroseconds = string
            .replacingOccurrences(of: microsecondsString, with: "")
            .replacingOccurrences(of: microsecondsPrefix, with: "")
        
        guard let date = self.date(from: dateStringExludingMicroseconds) else { return nil }
        let microsecondsInSecond = Double(1000000)
        let dateWithMicroseconds = date + microsecondsCount / microsecondsInSecond
        
        return dateWithMicroseconds
    }
}
