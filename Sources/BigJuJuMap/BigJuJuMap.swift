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
 This is an empty class. We use it to pin the bundle for the framework.
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
     This rescales a UIImage, to fit a given width, preserving the aspect.
     */
    func _scaledToWidth(_ inTargetWidth: CGFloat) -> UIImage {
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
 This is used to designate a location, with an attached data entity, and a handler callback.
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
     This allows us to return a resized market image.
     */
    private struct _BJJMAssets {
        static let _sMarkerWidthInDisplayUnits: CGFloat = 32  // (yours)

        /* ############################################################## */
        /**
         Returns the *unresolved* asset image (keeps imageAsset variants).
         */
        static func _genericMarkerBase() -> UIImage? {
            UIImage(named: "BJJM_Generic_Marker", in: ._bigJuJuMap, compatibleWith: nil)
        }

        /* ############################################################## */
        /**
         Returns a rendered marker image for the given traits (resolved + scaled).
         */
        static func _genericMarkerRendered(compatibleWith inTraits: UITraitCollection) -> UIImage {
            let base = _genericMarkerBase() ?? UIImage()
            let resolved = base.imageAsset?.image(with: inTraits) ?? base
            return resolved._scaledToWidth(_sMarkerWidthInDisplayUnits)
        }
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
         The coordinate for this annotation.
         */
        public var coordinate: CLLocationCoordinate2D { self.data.coordinate }
        
        /* ############################################################## */
        /**
         Any data associated with the annotation (may be aggregate, with multiple data items).
         */
        public var data: [any BigJuJuMapLocationProtocol]
        
        /* ############################################################## */
        /**
         Basic initializer
         - parameter inData: All data to be associated with the annotation
         */
        public init(_ inData: [any BigJuJuMapLocationProtocol]) {
            self.data = inData
        }
        
        /* ############################################################## */
        /**
         Allows a single data item.
         - parameter inData: A single data item.
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
         Find the largest font size that fits the rect (simple binary search).
         
         - parameter inText: The text to be drawn.
         - parameter inRect: The rectangle in which this is to be drawn.
         - parameter inMaxFontSize: The maximum font size.
         - parameter inMinFontSize: The minimum font size.
         - parameter inWeight: The text weight.
         - returns: The maximum font size that fits.
         */
        private static func _bestFittingFontSize(for inText: String,
                                                 in inRect: CGRect,
                                                 maxFontSize inMaxFontSize: CGFloat,
                                                 minFontSize inMinFontSize: CGFloat,
                                                 weight inWeight: UIFont.Weight
        ) -> CGFloat {
            guard inRect.width > 1, inRect.height > 1 else { return inMinFontSize }

            /* ########################################################## */
            /**
             */
            func _fits(_ inSize: CGFloat) -> Bool {
                let font = UIFont.systemFont(ofSize: inSize, weight: inWeight)
                let measured = (inText as NSString).size(withAttributes: [.font: font])
                return measured.width <= inRect.width && measured.height <= inRect.height
            }

            var low = inMinFontSize
            var high = inMaxFontSize
            var best = inMinFontSize

            for _ in 0..<18 {   // Eighteen tries, before we give up.
                let mid = (low + high) * 0.5
                if _fits(mid) {
                    best = mid
                    low = mid
                } else {
                    high = mid
                }
            }

            return best.rounded(.down)
        }

        /* ############################################################## */
        /**
         This displays a text item, with the number of aggregate data points.
         */
        private let _countTextLayer: CATextLayer = {
            let t = CATextLayer()
            t.zPosition = 10_000
            t.isHidden = true
            t.alignmentMode = .center
            t.truncationMode = .none
            t.isWrapped = false
            return t
        }()

        /* ############################################################## */
        /**
         The controller that "owns" the map.
         */
        public var myController: BigJuJuMapViewController?
        
        /* ############################################################## */
        /**
         The annotation attached to this view.
         */
        public var myAnnotation: LocationAnnotation? { self.annotation as? LocationAnnotation }
        
        /* ############################################################## */
        /**
         Basic initializer.
         - parameter inAnnotation: The annotation attached to this view.
         - parameter inReuseIdentifier: The reuse ID (optional,. default is nil).
         - parameter inController: The controller that "owns" the map.
         */
        public init(annotation inAnnotation: LocationAnnotation,
                    reuseIdentifier inReuseIdentifier: String? = nil,
                    controller inController: BigJuJuMapViewController? = nil
        ) {
            super.init(annotation: inAnnotation, reuseIdentifier: inReuseIdentifier)
            self.myController = inController
            let isSingle = (self.myAnnotation?.data.count ?? 0) == 1
            let base = isSingle ? inController?.singleMarkerImage : inController?.multiMarkerImage

            if let controller = inController {
                self.image = controller._markerImage(from: base, compatibleWith: controller.traitCollection)
            } else {
                self.image = base
            }

            layer.addSublayer(self._countTextLayer)
        }
        
        /* ############################################################## */
        /**
         This adds our number display layer.
         */
        public required init?(coder inCoder: NSCoder) {
            super.init(coder: inCoder)
            layer.addSublayer(self._countTextLayer)
        }
        
        /* ############################################################## */
        /**
         Called to lay out the views. We use this to populate aggregate markers.
         */
        public override func layoutSubviews() {
            super.layoutSubviews()

            self._countTextLayer.contentsScale =
                window?.windowScene?.screen.scale
                ?? traitCollection.displayScale

            let count = self.myAnnotation?.data.count ?? 0
            let show = (self.myController?.displayNumbers ?? false) && count > 1

            self._countTextLayer.isHidden = !show
            guard show else { return }

            let rect = bounds
            let drawBox = CGRect(
                x: 2,
                y: 4,
                width: rect.width - 4,
                height: rect.height * 0.5
            )

            let text = "\(count)"
            self._countTextLayer.string = text

            self._countTextLayer.foregroundColor = UIColor.systemBackground.cgColor

            let maxFontSize = max(6, drawBox.height)

            let fitted = Self._bestFittingFontSize(
                for: text,
                in: drawBox,
                maxFontSize: maxFontSize,
                minFontSize: 6,
                weight: .bold
            )

            let font = UIFont.systemFont(ofSize: fitted, weight: .bold)
            self._countTextLayer.font = font
            self._countTextLayer.fontSize = fitted

            let yOffset = max(0, (drawBox.height - font.lineHeight) * 0.5)
            self._countTextLayer.frame = drawBox.offsetBy(dx: 0, dy: yOffset)
        }
        
        /* ############################################################## */
        /**
         Draws the image for the marker.
         
         - parameter rect: The rectangle in which this is to be drawn.
         */
        open override func draw(_ rect: CGRect) {
            image?.draw(in: rect)
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
    public var singleMarkerImage: UIImage? = _BJJMAssets._genericMarkerBase()

    /* ################################################################## */
    /**
     The image to be used for markers, representing aggregated locations.
     */
    @IBInspectable
    public var multiMarkerImage: UIImage? = _BJJMAssets._genericMarkerBase()

    /* ################################################################## */
    /**
     If true, multiple (aggregate) markers will display the number of elements aggregated.
     */
    @IBInspectable
    public var displayNumbers:Bool = true
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
     This returns a marker image that will change when the markers are recalculated.
     - parameter inBase: The image that we resize (the original asset).
     - parameter inTraits: The traits style (light or dark) that we want.
     - returns: A scaled, appropriate marker image.
     */
    private func _markerImage(from inBase: UIImage?, compatibleWith inTraits: UITraitCollection) -> UIImage {
        let base = inBase ?? _BJJMAssets._genericMarkerBase() ?? UIImage()
        let resolved = base.imageAsset?.image(with: inTraits) ?? base
        return resolved._scaledToWidth(_BJJMAssets._sMarkerWidthInDisplayUnits)
    }

    /* ################################################################## */
    /**
     This forces the annotations to be recalculated, and set to the map.
     */
    private func _recalculateAnnotations() {
        self.mapView.removeAnnotations(self.mapView.annotations)
        self.mapView.addAnnotations(self._myAnnotations)
    }
    
    /* ################################################################## */
    /**
     This creates clusters (multi) annotations, where markers would be close together.
     The Apple clustering algorithm kinda sucks, so we'll do it, ourselves.
     
     - parameter inAnnotations: The annotations to test.
     - returns: A new set of annotations, including any clusters.
     */
    private func _clusterAnnotations(_ inAnnotations: [LocationAnnotation]) -> [LocationAnnotation] {
        /* ############################################################## */
        // MARK: One Cell Location (Used as a Key)
        /* ############################################################## */
        /**
         We use this to approximate locations.
         */
        struct _CellKey: Hashable {
            /* ########################################################## */
            /**
             The hashable integer interpretation of the point X-axis
             */
            let x: Int

            /* ########################################################## */
            /**
             The hashable integer interpretation of the point Y-axis
             */
            let y: Int
        }
        
        /* ############################################################## */
        // MARK: Generate a Cell Key From a Coordinate
        /* ############################################################## */
        /**
         - parameter inPoint: The floating-point coords we'll use.
         - returns: A new CellKey struct, made from the given point.
         */
        func _cellKey(for inPoint: CGPoint) -> _CellKey {
            _CellKey(
                x: Int(floor(inPoint.x / cellSize)),
                y: Int(floor(inPoint.y / cellSize))
            )
        }
        
        guard !inAnnotations.isEmpty,
              !mapView.bounds.isEmpty,
              8 < _BJJMAssets._sMarkerWidthInDisplayUnits
        else { return [] }
        
        // Cluster size in screen points.
        let cellSize = _BJJMAssets._sMarkerWidthInDisplayUnits
        
        // We store the cluster annotation and an approximate screen-center for neighbor checks.
        var clusters: [_CellKey: LocationAnnotation] = [:]
        var centers: [_CellKey: CGPoint] = [:]
        
        for annotation in inAnnotations {
            let point = self.mapView.convert(annotation.coordinate, toPointTo: self.mapView)
            let baseKey = _cellKey(for: point)
            
            // Try to find an existing cluster in this cell, or adjacent cells, that are within one marker-width on screen.
            var matchKey: _CellKey? = nil
            
            // Yeah, that looks like a GOTO... (Makes sure that break takes us all the way out).
            outer: for deltaX in -1...1 {
                for deltaY in -1...1 {
                    let key = _CellKey(x: baseKey.x + deltaX, y: baseKey.y + deltaY)
                    if let center = centers[key] {
                        let delta = hypot(center.x - point.x, center.y - point.y)
                        if delta <= cellSize {
                            matchKey = key
                            break outer
                        }
                    }
                }
            }
            
            let useKey = matchKey ?? baseKey
            
            if let existing = clusters[useKey] {
                // Merge: keep the existing annotation object, just append data.
                existing.data.append(contentsOf: annotation.data)
                
                // Update stored screen center (simple running average by item-count).
                let oldCenter = centers[useKey] ?? point
                let oldCount = max(1, existing.data.count - annotation.data.count)
                let newCount = existing.data.count
                let t = CGFloat(oldCount) / CGFloat(newCount)
                centers[useKey] = CGPoint(
                    x: oldCenter.x * t + point.x * (1 - t),
                    y: oldCenter.y * t + point.y * (1 - t)
                )
            } else {
                clusters[useKey] = annotation
                centers[useKey] = point
            }
        }
        
        return Array(clusters.values)
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
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
                self._recalculateAnnotations()
            }
        }
    }
    
    /* ################################################################## */
    /**
     This will force a recalculation, when the trait style changes.
     
     - parameter inPreviousTraitCollection: The prior trait style.
     */
    @available(iOS, deprecated: 17.0)
    public override func traitCollectionDidChange(_ inPreviousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(inPreviousTraitCollection)

        guard
            let inPreviousTraitCollection,
            traitCollection.hasDifferentColorAppearance(comparedTo: inPreviousTraitCollection)
        else {
            return
        }

        _recalculateAnnotations()
    }
}

/* ################################################################################################################################## */
// MARK: MKMapViewDelegate Conformance
/* ################################################################################################################################## */
extension BigJuJuMapViewController: MKMapViewDelegate {
    /* ################################################################## */
    /**
     Returns the appropriate marker view for an annotation.
     
     - parameter inMapView: The map view the annotation is attached to.
     - parameter inAnnotation: The annotation for the marker.
     - returns: A new annotation view instance.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView, viewFor inAnnotation: any MKAnnotation) -> MKAnnotationView? {
        guard let annotation = inAnnotation as? LocationAnnotation else { return nil }
        return AnnotationView(annotation: annotation, controller: self)
    }
    
    /* ################################################################## */
    /**
     Called when the map has finished rendering all its tiles. We use it to force the annotations to be recalculated.
     
     - parameter inMapView: The map view being rendered.
     - parameter fullyRendered: Ignored.
     */
    @MainActor
    public func mapViewDidFinishRenderingMap(_ inMapView: MKMapView, fullyRendered: Bool) {
        self._recalculateAnnotations()
    }
    
    /* ################################################################## */
    /**
     Called when the map has changed its region. We use it to force the annotations to be recalculated.

     - parameter inMapView: The map view being rendered.
     - parameter regionDidChangeAnimated: Ignored.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView, regionDidChangeAnimated: Bool) {
        self._recalculateAnnotations()
    }
}
