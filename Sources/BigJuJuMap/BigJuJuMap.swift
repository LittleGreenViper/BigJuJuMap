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
// MARK: - Private Class, Used to Pin the Bundle -
/* ################################################################################################################################## */
/**
 This is an empty class
 */
private final class _BJJMBundleToken: NSObject { }

/* ################################################################################################################################## */
// MARK: - Private Bundle Extension, to Get the Framework Bundle -
/* ################################################################################################################################## */
private extension Bundle {
    /* ################################################################## */
    /**
     The bundle that contains BigJuJuMap.framework resources (Media.xcassets, etc.)
     */
    static let _bigJuJuMap: Bundle = Bundle(for: _BJJMBundleToken.self)
}

/* ################################################################################################################################## */
// MARK: - Private UIImage Extension, to Add Simple Resizing Function -
/* ################################################################################################################################## */
private extension UIImage {
    /* ################################################################## */
    /**
     */
    func scaledToWidth(_ inTargetWidth: CGFloat) -> UIImage {
        guard inTargetWidth > 0,
              size.width > 0,
              size.height > 0
        else { return self }

        let scaleFactor = inTargetWidth / size.width
        let targetSize = CGSize(width: inTargetWidth, height: size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale   // preserves retina scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

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
    // MARK: Special Default Marker Enum
    /* ############################################################################################################################## */
    /**
     */
    private enum _BJJMAssets {
        /* ################################################################## */
        /**
         Marker Width, in Display Units
         */
        static let _sMarkerWidthInDisplayUnits = CGFloat(24)

        /* ################################################################## */
        /**
         The generic marker.
         */
        static let genericMarker: UIImage = {
            return UIImage(named: "BJJM_Generic_Marker", in: ._bigJuJuMap, compatibleWith: nil)?.scaledToWidth(Self._sMarkerWidthInDisplayUnits) ?? UIImage()
        }()
    }
    
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

    /* ############################################################################################################################## */
    // MARK: Custom Annotation View Class
    /* ############################################################################################################################## */
    /**
     This is used to display a map marker.
     */
    open class AnnotationView: MKAnnotationView {
        /* ############################################################## */
        /**
         */
        public var myController: BigJuJuMapViewController?
        
        /* ############################################################## */
        /**
         */
        public var myAnnotation: LocationAnnotation? { self.annotation as? LocationAnnotation }
        
        /* ############################################################## */
        /**
         */
        public init(annotation inAnnotation: LocationAnnotation, reuseIdentifier inReuseIdentifier: String? = nil, controller inController: BigJuJuMapViewController? = nil) {
            super.init(annotation: inAnnotation, reuseIdentifier: inReuseIdentifier)
            self.myController = inController
            let image = self.myAnnotation?.data.count == 1 ? inController?.singleMarkerImage : inController?.multiMarkerImage
            #if DEBUG
                print("Marker View Created for \(inAnnotation.data.count) locations")
            #endif
            self.image = image
        }
        
        /* ############################################################## */
        /**
         */
        required public init?(coder inDecoder: NSCoder) {
            super.init(coder: inDecoder)
        }
        
        /* ############################################################## */
        /**
         Draws the image for the marker.
         
         - parameter rect: The rectangle in which this is to be drawn.
         */
        open override func draw(_ rect: CGRect) {
            self.image?.draw(in: rect)
        }
    }
    
    /* ################################################################## */
    /**
     The maximum number of rows we can display in a popover.
     */
    private static let _maximumNumberOfItemsToDisplay = 1000

    /* ################################################################## */
    /**
     The data for the map to display.
     
     Each item will be displayed in a marker. Markers may be aggregated.
     */
    public var mapData: [any BigJuJuMapLocationProtocol] = [] { didSet { DispatchQueue.main.async { self._recalculateAnnotations() } } }
    
    /* ################################################################## */
    /**
     The main view of this controller is a map. This simply casts that.
     
     > NOTE: This does an implicit unwrap, because we are in deep poo, if it fails.
     */
    public var mapView: MKMapView { self.view as! MKMapView }
    
    /* ################################################################## */
    /**
     The image to be used for markers, representing single locations.
     */
    @IBInspectable
    public var singleMarkerImage: UIImage? = _BJJMAssets.genericMarker
    
    /* ################################################################## */
    /**
     The image to be used for markers, representing aggregated locations.
     */
    @IBInspectable
    public var multiMarkerImage: UIImage? = _BJJMAssets.genericMarker
}

/* ################################################################################################################################## */
// MARK: Private Computed Properties
/* ################################################################################################################################## */
extension BigJuJuMapViewController {
    /* ################################################################## */
    /**
     This creates annotations for the meeting search results.
     
     - returns: An array of annotations (may be empty).
     */
    var _myAnnotations: [LocationAnnotation] {
        let rawAnnotations = self.mapData.map { LocationAnnotation($0) }
        return self._clusterAnnotations(rawAnnotations)
    }
}

/* ################################################################################################################################## */
// MARK: Private Instance Methods
/* ################################################################################################################################## */
extension BigJuJuMapViewController {
    /* ################################################################## */
    /**
     */
    private func _recalculateAnnotations() {
        self.mapView.removeAnnotations(self.mapView.annotations)
        self.mapView.addAnnotations(self._myAnnotations)
    }
    
    /* ################################################################## */
    /**
     This creates clusters (multi) annotations, where markers would be close together.
     
     - parameter inAnnotations: The annotations to test.
     - returns: A new set of annotations, including any clusters.
     */
    private func _clusterAnnotations(_ inAnnotations: [LocationAnnotation]) -> [LocationAnnotation] {
        let mapRect = mapView.visibleMapRect
        let mapBounds = mapView.bounds
        let centerLat = mapView.centerCoordinate.latitude

        guard !mapRect.isEmpty, !mapBounds.isEmpty else { return [] }

        let thresholdDistanceInMeters =
            (_BJJMAssets._sMarkerWidthInDisplayUnits / 2)
            * ((MKMetersPerMapPointAtLatitude(centerLat) * mapRect.size.width) / mapBounds.size.width)

        guard thresholdDistanceInMeters > 0 else { return [] }

        return inAnnotations.reduce(into: [LocationAnnotation]()) { result, next in
            let nextLocation = CLLocation(latitude: next.coordinate.latitude, longitude: next.coordinate.longitude)

            if let idx = result.firstIndex(where: {
                thresholdDistanceInMeters >= CLLocation(latitude: $0.coordinate.latitude,
                                                       longitude: $0.coordinate.longitude)
                    .distance(from: nextLocation)
            }) {
                if result[idx].data.count < Self._maximumNumberOfItemsToDisplay {
                    result[idx].data.append(contentsOf: next.data)
                }
            } else {
                result.append(next)
            }
        }
    }
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
        self.mapView.delegate = self
    }
}

/* ################################################################################################################################## */
// MARK: MKMapViewDelegate Conformance
/* ################################################################################################################################## */
extension BigJuJuMapViewController: MKMapViewDelegate {
    /* ################################################################## */
    /**
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView, viewFor inAnnotation: any MKAnnotation) -> MKAnnotationView? {
        guard let annotation = inAnnotation as? LocationAnnotation else { return nil }
        return AnnotationView(annotation: annotation, controller: self)
    }
    
    /* ################################################################## */
    /**
     */
    @MainActor
    public func mapViewDidFinishRenderingMap(_ inMapView: MKMapView, fullyRendered inFullyRendered: Bool) {
        self._recalculateAnnotations()
    }
}
