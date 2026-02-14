/*
 © Copyright 2026, Little Green Viper Software Development LLC
 LICENSE:
 
 MIT License
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
 modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation
import TabularData
import CoreLocation
import BigJuJuMap
import UIKit

/* ################################################################################################################################## */
// MARK: - Location Data "Factory" Struct -
/* ################################################################################################################################## */
/**
 This is s simple static struct, that provides a dataframe for a given filename (for a CSV-encoded location file).
 */
struct BJJM_LocationFactory {
    /* ################################################################## */
    /**
     Returns a DataFrame for the given filename.
     
     - parameter inFileName: The filename of the CSV file we're using.
     - returns: A new DataFrame instance, filled with the contents of that file.
     */
    static func locationData(from inFileName: String) -> DataFrame? {
        let csvOptions = CSVReadingOptions(hasHeaderRow: true,
                                           delimiter: ","
        )

        guard let csvDataURL = Bundle.main.url(forResource: inFileName,
                                               withExtension: "csv"
        ),
              let dataFrame = try? DataFrame(contentsOfCSVFile: csvDataURL,
                                             options: csvOptions
              )
        else { return nil }

        return dataFrame
    }
}

/* ################################################################################################################################## */
// MARK: - DataFrame Helpers -
/* ################################################################################################################################## */
/**
 This provides some simple filtering and casting methods.
 */
extension DataFrame.Row {
    /* ################################################################## */
    /**
     Parses a string from the column.
     
     - parameter inColumn: The column data, in string format.
     - returns: The column value, as a String
     */
    func string(_ inColumn: String) -> String? {
        if let string_version = self[inColumn] as? String { return string_version }
        return nil
    }

    /* ################################################################## */
    /**
     Parses an int from the column.
     
     - parameter inColumn: The column data, in string format.
     - returns: The column value, as an Int
     */
    func int(_ inColumn: String) -> Int? {
        if let int_version = self[inColumn] as? Int { return int_version }
        if let string_version = self[inColumn] as? String { return Int(string_version.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let double_version = self[inColumn] as? Double { return Int(double_version) }
        return nil
    }

    /* ################################################################## */
    /**
     Parses a double from the column.
     
     - parameter inColumn: The column data, in string format.
     - returns: The column value, as a Double
     */
    func double(_ inColumn: String) -> Double? {
        if let double_version = self[inColumn] as? Double { return double_version }
        if let int_version = self[inColumn] as? Int { return Double(int_version) }
        if let string_version = self[inColumn] as? String {
            return Double(string_version.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

/* ################################################################################################################################## */
// MARK: Marker Type Selection Enum
/* ################################################################################################################################## */
/**
 These are the marker types we'll be using.
 */
enum BJJM_MarkerType: Int {
    /* ################################################################## */
    /**
     This one is provided by the library. It's a very simple "upside-down teardrop" shape.
     */
    case builtIn

    /* ################################################################## */
    /**
     This is a simple custom shape that provides space for numbers.
     */
    case customEnumerated

    /* ################################################################## */
    /**
     This is a more complex one, that has color, and no space for numbers.
     */
    case customNonEnumerated
}

/* ################################################################################################################################## */
// MARK: Concrete Map Location Class
/* ################################################################################################################################## */
/**
 This class implements the data item protocol.
 */
final class BJJM_MapLocation: BigJuJuMapLocationProtocol {
    /* ################################################################## */
    /**
     Makes the sendable/hashable explicitly an Int.
     */
    typealias ID = Int

    /* ################################################################## */
    /**
     Makes it identifiable.
     */
    let id: ID
    
    /* ################################################################## */
    /**
     Has a basic location
     */
    let location: CLLocation
    
    /* ################################################################## */
    /**
     Has a name
     */
    let name: String
    
    /* ################################################################## */
    /**
     This is called when the location is chosen on the map.
     */
    let handler: @Sendable (any BigJuJuMapLocationProtocol) -> Void
    
    /* ################################################################## */
    /**
     If supplied, an alternat color to use for the text display in the popover.
     */
    let textColor: UIColor?
    
    /* ################################################################## */
    /**
     If supplied, an alternat font to use for the text display in the popover.
     */
    let textFont: UIFont?

    /* ################################################################## */
    /**
     Basic initializer
     
     - parameter inID: The hashable identifier
     - parameter inName: The string to be applied.
     - parameter inLat: The latitude
     - parameter inLng: The longitude
     - parameter inTextColor: If supplied, an alternat color to use for the text display in the popover. Optional. Default is nil.
     - parameter inTextFont: If supplied, an alternat font to use for the text display in the popover. Optional. Default is nil.
     - parameter inHandler: The handler closure. Optional. Default does nothing.
     */
    init(id inID: ID,
         name inName: String,
         latitude inLat: CLLocationDegrees,
         longitude inLng: CLLocationDegrees,
         textColor inTextColor: UIColor? = nil,
         textFont inTextFont: UIFont? = nil,
         handler inHandler: @escaping @Sendable (any BigJuJuMapLocationProtocol) -> Void = { _ in }
    ) {
        self.id = inID
        self.name = inName
        self.location = CLLocation(latitude: inLat, longitude: inLng)
        self.textColor = inTextColor
        self.textFont = inTextFont
        self.handler = inHandler
    }
}

