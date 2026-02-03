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

import UIKit
import BigJuJuMap
import TabularData
import CoreLocation
import RVS_Generic_Swift_Toolbox

/* ################################################################################################################################## */
// MARK: - DataFrame Helpers -
/* ################################################################################################################################## */
/**
 
 */
fileprivate extension DataFrame.Row {
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
// MARK: - Main View Controller Class -
/* ################################################################################################################################## */
/**
 
 */
class BJJM_ViewController: UIViewController {
    /* ############################################################################################################################## */
    // MARK: Marker Type Selection Enum
    /* ############################################################################################################################## */
    /**
     */
    private enum _MarkerType: Int {
        /* ############################################################## */
        /**
         */
        case builtIn

        /* ############################################################## */
        /**
         */
        case customEnumerated

        /* ############################################################## */
        /**
         */
        case customNonEnumerated
    }
    
    /* ############################################################################################################################## */
    // MARK: Concrete Map Location Class
    /* ############################################################################################################################## */
    /**
     This class implements the data item protocol.
     */
    final class BJJM_MapLocation: BigJuJuMapLocationProtocol {
        /* ############################################################## */
        /**
         Makes it identifiable.
         */
        var id: AnyHashable
        
        /* ############################################################## */
        /**
         Has a basic location
         */
        let location: CLLocation
        
        /* ############################################################## */
        /**
         Has a name
         */
        let name: String
        
        /* ############################################################## */
        /**
         This is called when the location is chosen on the map.
         */
        let handler: ((_ item: any BigJuJuMapLocationProtocol) -> Void)
        
        /* ############################################################## */
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
    
    /* ################################################################## */
    /**
     */
    private weak var _myMapController: BigJuJuMapViewController?
    
    /* ################################################################## */
    /**
     The switch that selects our map data.
     */
    @IBOutlet weak var dataSelectorSwitch: UISegmentedControl?
    
    /* ################################################################## */
    /**
     */
    @IBOutlet weak var markerSelectorSwitch: UISegmentedControl?
}

/* ################################################################################################################################## */
// MARK: Private Computed Properties
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     */
    private var _locationData: DataFrame? {
        let selectedIndex = self.dataSelectorSwitch?.selectedSegmentIndex ?? 0
        let fileName = self.dataSelectorSwitch?.titleForSegment(at: selectedIndex) ?? "SLUG-USA".localizedVariant
        let csvOptions = CSVReadingOptions(hasHeaderRow: true, delimiter: ",")

        guard let csvDataURL = Bundle.main.url(forResource: fileName, withExtension: "csv"),
              let dataFrame = try? DataFrame(contentsOfCSVFile: csvDataURL, options: csvOptions)
        else { return nil }

        return dataFrame
    }
}

/* ################################################################################################################################## */
// MARK: Private Instance Methods
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     */
    private func _updateLocations() {
        guard let dataFrame = self._locationData,
              let myController = self._myMapController
        else { return }
        
        let locations: [any BigJuJuMapLocationProtocol] = dataFrame.rows.compactMap { inRow in
            guard let id = inRow.int("id"),
                  let name = inRow.string("name"),
                  let latitude = inRow.double("latitude"),
                  let longitude = inRow.double("longitude")
            else { return nil }

            return BJJM_MapLocation(id: id, name: name, latitude: latitude, longitude: longitude) { inItem in
                print("Tapped: \(inItem.name) @ \(inItem.location.coordinate.latitude), \(inItem.location.coordinate.longitude)")
            }
        }

        #if DEBUG
            print("Loaded \(locations.count) map locations.")
        #endif

        switch markerSelectorSwitch?.selectedSegmentIndex {
        case _MarkerType.customEnumerated.rawValue:
            myController.singleMarkerImage = UIImage(named: "CustomGeneric")
            myController.multiMarkerImage = UIImage(named: "CustomGeneric")
            myController.displayNumbers = true

        case _MarkerType.customNonEnumerated.rawValue:
            myController.singleMarkerImage = UIImage(named: "CustomSingle")
            myController.multiMarkerImage = UIImage(named: "CustomMulti")
            myController.displayNumbers = false

        default:
            myController.singleMarkerImage = nil
            myController.multiMarkerImage = nil
            myController.displayNumbers = true
        }
        myController.mapData = locations
        myController.region = locations.containingCoordinateRegion
    }
}

/* ################################################################################################################################## */
// MARK: Callbacks
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     The switch that selects our map data was changed.
     */
    @IBAction func selectorSwitchHit() {
        self._updateLocations()
    }
}

/* ################################################################################################################################## */
// MARK: Base Class Overrides
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     */
    override func viewDidLoad() {
        /* ############################################################## */
        /**
         */
        func _recursiveImageTweaker(root inView: UIView) {
            if let imageView = inView as? UIImageView {
                imageView.contentMode = .scaleAspectFit
            }
            
            inView.subviews.forEach { _recursiveImageTweaker(root: $0) }
        }
        
        super.viewDidLoad()
        
        guard let dataSelectorSwitch,
              let markerSelectorSwitch
        else { return }

        for index in 0..<dataSelectorSwitch.numberOfSegments {
            dataSelectorSwitch.setTitle(dataSelectorSwitch.titleForSegment(at: index)?.localizedVariant, forSegmentAt: index)
        }
        
        _recursiveImageTweaker(root: markerSelectorSwitch)

        self._updateLocations()
    }
    
    /* ################################################################## */
    /**
     This just allows us to access the BigJuJuMap instance, so we can directly initialize it.
     
     - parameter inSegue: The segue being executed.
     - parameter sender: Ignored.
     */
    override func prepare(for inSegue: UIStoryboardSegue, sender: Any?) {
        self._myMapController = inSegue.destination as? BigJuJuMapViewController
    }
}
