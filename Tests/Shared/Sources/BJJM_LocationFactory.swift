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

/* ################################################################################################################################## */
// MARK: - Location Data "Factory" Struct -
/* ################################################################################################################################## */
/**
 
 */
struct BJJM_LocationFactory {
    /* ################################################################## */
    /**
     */
    static func locationData(from inFileName: String) -> DataFrame? {
        let csvOptions = CSVReadingOptions(hasHeaderRow: true, delimiter: ",")

        guard let csvDataURL = Bundle.main.url(forResource: inFileName, withExtension: "csv"),
              let dataFrame = try? DataFrame(contentsOfCSVFile: csvDataURL, options: csvOptions)
        else { return nil }

        return dataFrame
    }
}

/* ################################################################################################################################## */
// MARK: - DataFrame Helpers -
/* ################################################################################################################################## */
/**
 
 */
extension DataFrame.Row {
    /* ################################################################## */
    /**
     */
    func string(_ inColumn: String) -> String? {
        if let s = self[inColumn] as? String { return s }
        return nil
    }

    /* ################################################################## */
    /**
     */
    func int(_ inColumn: String) -> Int? {
        if let i = self[inColumn] as? Int { return i }
        if let s = self[inColumn] as? String { return Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let d = self[inColumn] as? Double { return Int(d) }
        return nil
    }

    /* ################################################################## */
    /**
     */
    func double(_ inColumn: String) -> Double? {
        if let d = self[inColumn] as? Double { return d }
        if let i = self[inColumn] as? Int { return Double(i) }
        if let s = self[inColumn] as? String {
            return Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

/* ################################################################################################################################## */
// MARK: Marker Type Selection Enum
/* ################################################################################################################################## */
/**
 */
enum BJJM_MarkerType: Int {
    /* ################################################################## */
    /**
     */
    case builtIn

    /* ################################################################## */
    /**
     */
    case customEnumerated

    /* ################################################################## */
    /**
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
     Makes it identifiable.
     */
    var id: AnyHashable
    
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
    let handler: ((_ item: any BigJuJuMapLocationProtocol) -> Void)
    
    /* ################################################################## */
    /**
     Basic initializer
     - parameter inID: The hashable identifier
     - parameter inName: The string to be applied.
     - parameter inLat: The latitude
     - parameter inLng: The longitude
     - parameter handler: The handler closure.
     */
    init(id inID: AnyHashable,
         name inName: String,
         latitude inLat: CLLocationDegrees,
         longitude inLng: CLLocationDegrees,
         handler inHandler: @escaping ((_ inItem: any BigJuJuMapLocationProtocol) -> Void) = { _ in }) {
        self.id = inID
        self.name = inName
        self.location = CLLocation(latitude: inLat, longitude: inLng)
        self.handler = inHandler
    }
}

