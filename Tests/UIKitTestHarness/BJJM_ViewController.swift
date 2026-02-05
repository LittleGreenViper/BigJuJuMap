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
// MARK: - Main View Controller Class -
/* ################################################################################################################################## */
/**
 This displays a view, with the map filling the screen, behind  two segmented switches for selecting the marker and the dataset.
 */
class BJJM_ViewController: UIViewController {
    /* ################################################################## */
    /**
     This is the instance of the BigJuJuMap, from the package.
     */
    private weak var _myMapController: BigJuJuMapViewController?
    
    /* ################################################################## */
    /**
     The switch that selects the marker type.
     */
    @IBOutlet weak var markerSelectorSwitch: UISegmentedControl?

    /* ################################################################## */
    /**
     The switch that selects our map data.
     */
    @IBOutlet weak var dataSelectorSwitch: UISegmentedControl?
}

/* ################################################################################################################################## */
// MARK: Private Computed Properties
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     This is the selected dataset, in a dataframe.
     */
    private var _locationData: DataFrame? {
        let selectedIndex = self.dataSelectorSwitch?.selectedSegmentIndex ?? 0
        let fileName = self.dataSelectorSwitch?.titleForSegment(at: selectedIndex) ?? "SLUG-USA".localizedVariant
        return BJJM_LocationFactory.locationData(from: fileName)
    }
}

/* ################################################################################################################################## */
// MARK: Private Instance Methods
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     This forces the map controller to change its markers to the selected type.
     */
    private func _updateMarkers() {
        guard let myController = self._myMapController else { return }
        
        switch markerSelectorSwitch?.selectedSegmentIndex {
        case BJJM_MarkerType.customEnumerated.rawValue:
            myController.singleMarkerImage = UIImage(named: "CustomGeneric")
            myController.multiMarkerImage = UIImage(named: "CustomGeneric")
            myController.displayNumbers = true
            
        case BJJM_MarkerType.customNonEnumerated.rawValue:
            myController.singleMarkerImage = UIImage(named: "CustomSingle")
            myController.multiMarkerImage = UIImage(named: "CustomMulti")
            myController.displayNumbers = false
            
        default:
            myController.singleMarkerImage = nil
            myController.multiMarkerImage = nil
            myController.displayNumbers = true
        }
    }
    
    /* ################################################################## */
    /**
     This forces the map controller to use the selected dataset.
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
            
            return BJJM_MapLocation(id: id, name: name, latitude: latitude, longitude: longitude) { [weak self] inItem in
                guard let self else { return }
                let alertMessage = String(format: "SLUG-ALERT-FORMAT".localizedVariant, inItem.name)

                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "SLUG-ALERT-HEADER".localizedVariant, message: alertMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "SLUG-OK".localizedVariant, style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
        
        myController.mapData = locations
        // We change the map region to show the data points.
        myController.visibleRect = locations.containingMapRectDatelineAware
    }
}

/* ################################################################################################################################## */
// MARK: Callbacks
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     The switch that selects our map markers was changed.
     */
    @IBAction func locationSelectorSwitchHit() {
        self._updateLocations()
    }
    
    /* ################################################################## */
    /**
     The switch that selects our map data was changed.
     */
    @IBAction func markerSelectorSwitchHit() {
        self._updateMarkers()
    }
}

/* ################################################################################################################################## */
// MARK: Base Class Overrides
/* ################################################################################################################################## */
extension BJJM_ViewController {
    /* ################################################################## */
    /**
     Called when the view has loaded.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let dataSelectorSwitch,
              let markerSelectorSwitch
        else { return }

        for index in 0..<markerSelectorSwitch.numberOfSegments {
            markerSelectorSwitch.setTitle(markerSelectorSwitch.titleForSegment(at: index)?.localizedVariant, forSegmentAt: index)
        }

        for index in 0..<dataSelectorSwitch.numberOfSegments {
            dataSelectorSwitch.setTitle(dataSelectorSwitch.titleForSegment(at: index)?.localizedVariant, forSegmentAt: index)
        }

        self._updateLocations()
    }
    
    /* ################################################################## */
    /**
     This just allows us to access the BigJuJuMap instance, so we can directly affect it.
     
     - parameter inSegue: The segue being executed.
     - parameter sender: Ignored.
     */
    override func prepare(for inSegue: UIStoryboardSegue, sender: Any?) {
        self._myMapController = inSegue.destination as? BigJuJuMapViewController
    }
}
