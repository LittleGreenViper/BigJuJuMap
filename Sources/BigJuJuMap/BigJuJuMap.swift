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
import MapKit

/* ################################################################################################################################## */
// MARK: Map Location Template Protocol
/* ################################################################################################################################## */
/**
 
 */
public protocol BigJuJuMapLocationProtocol: AnyObject, Identifiable {
    /* ################################################################## */
    /**
     A unique, hashable value, identifying the instance.
     */
    var id: AnyHashable { get }
    
    /* ################################################################## */
    /**
     The location, associated with this data point.
     */
    var location: CLLocation { get }
    
    /* ################################################################## */
    /**
     A string, identifying this item, for use in displayed popovers.
     */
    var name: String { get }
    
    /* ################################################################## */
    /**
     This is a handler that is provided by the implementation.
     
     - parameter item: The instance of this protocol, associated with the handler.
     */
    var handler: ((_ item: any BigJuJuMapLocationProtocol) -> Void) { get }
    
    /* ################################################################## */
    /**
     This simply calls the handler, in whatever way is implemented.
     OPTIONAL: Default calls the handler in the main thread, with this instance as its parameter.
     */
    func callHandler()
}

/* ################################################################################################################################## */
// MARK: Defaults
/* ################################################################################################################################## */
public extension BigJuJuMapLocationProtocol {
    /* ################################################################## */
    /**
     This just calls the handler in the main thread, with this instance as its parameter.
     */
    func callHandler() { DispatchQueue.main.async { self.handler(self) } }
}

/* ################################################################################################################################## */
// MARK: Special Collection Extension, for aggregated data.
/* ################################################################################################################################## */
public extension Collection where Element == any BigJuJuMapLocationProtocol {
    /* ################################################################## */
    /**
     Returns the arithmetic mean (center) of the coordinates.
     */
    var coordinate: CLLocationCoordinate2D {
        guard !self.isEmpty else { return kCLLocationCoordinate2DInvalid }

        var latSum = 0.0
        var lonSum = 0.0

        self.forEach {
            latSum += $0.location.coordinate.latitude
            lonSum += $0.location.coordinate.longitude
        }

        let count = Double(self.count)

        return CLLocationCoordinate2D(
            latitude: latSum / count,
            longitude: lonSum / count
        )
    }
}

/* ################################################################################################################################## */
// MARK: Big Map View Controller Class
/* ################################################################################################################################## */
/**
 This is the heart of this package.
 
 It is a UIViewController, with a single, full-fill MKMapView. That view will have markers, designating the data provided.
 
 Selecting a marker, will pop up a callout, with the data item name. If it is an aggregate annotation, then the callout will contain a list.
 
 Selecting an item in the list, will trigger the `callHandler()` function, associated with that annotation.
 */
@IBDesignable
open class BigJuJuMapViewController: UIViewController {
    /* ############################################################################################################################## */
    // MARK: Custom Annotation Class
    /* ############################################################################################################################## */
    /**
     This is used to denote a single annotation item
     */
    open class LocationAnnotation: NSObject, MKAnnotation {
        /* ############################################################## */
        /**
         */
        public var coordinate: CLLocationCoordinate2D { self.data.coordinate }
        
        /* ############################################################## */
        /**
         */
        public var data: [any BigJuJuMapLocationProtocol]
        
        /* ############################################################## */
        /**
         */
        public init(_ inData: [any BigJuJuMapLocationProtocol]) {
            self.data = inData
        }
        
        /* ############################################################## */
        /**
         */
        public convenience init(_ inData: any BigJuJuMapLocationProtocol) {
            self.init([inData])
        }
    }
    
    /* ################################################################## */
    /**
     The data for the map to display.
     
     Each item will be displayed in a marker. Markers may be aggregated.
     */
    public var mapData: [any BigJuJuMapLocationProtocol] = []
    
    /* ################################################################## */
    /**
     The main view of this controller is a map. This simply casts that.
     
     > NOTE: This does an implicit unwrap, because we are in deep poo, if it fails.
     */
    public var mapView: MKMapView { self.view as! MKMapView }
    
    /* ################################################################## */
    /**
     The image to be used for markers, representing single locations.
     
     Default is a supplied resource image, named `"BJJM_Marker_Single"`
     */
    @IBInspectable
    public var singleMarkerImage: UIImage? = UIImage(named: "BJJM_Marker_Single")
    
    /* ################################################################## */
    /**
     The image to be used for markers, representing aggregated locations.
     
     Default is a supplied resource image, named `"BJJM_Marker_Multi"`
     */
    @IBInspectable
    public var multiMarkerImage: UIImage? = UIImage(named: "BJJM_Marker_Multi")
}

/* ################################################################################################################################## */
// MARK: Public Instance Methods
/* ################################################################################################################################## */
extension BigJuJuMapViewController {
    /* ################################################################## */
    /**
     Called when the view hierarchy has completed loading, but before it is laid out and displayed.
     */
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view = MKMapView()
    }
}
