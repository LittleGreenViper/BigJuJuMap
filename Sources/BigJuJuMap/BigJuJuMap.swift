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
              self.size.width > 0,
              self.size.height > 0
        else { return self }

        let scaleFactor = inTargetWidth / self.size.width
        let targetSize = CGSize(width: inTargetWidth, height: self.size.height * scaleFactor)

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
     
     - parameter inItem: The instance of this protocol, associated with the handler.
     */
    var handler: ((_ inItem: any BigJuJuMapLocationProtocol) -> Void) { get }
    
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
// MARK: - Private MKMapView Subclass for Deterministic Annotation Hit-Testing -
/* ################################################################################################################################## */
/**
 
 */
private final class _BJJMMapView: MKMapView {
    /* ################################################################## */
    /**
     Recursively collect all MKAnnotationView instances in the view hierarchy.
     */
    private func _allAnnotationViews(in inView: UIView) -> [MKAnnotationView] {
        var ret: [MKAnnotationView] = []
        
        if let av = inView as? MKAnnotationView {
            ret.append(av)
        }
        
        for sub in inView.subviews {
            ret.append(contentsOf: _allAnnotationViews(in: sub))
        }
        
        return ret
    }
    
    /* ################################################################## */
    /**
     Overrides hit-testing so that, when multiple annotation views overlap,
     we deterministically pick the annotation whose *tip* (bottom-center) is closest to the tap.
     */
    override func hitTest(_ inPoint: CGPoint, with inEvent: UIEvent?) -> UIView? {
        // First: let the system find its preferred target (works for non-overlapping cases, controls, etc.).
        let systemHit = super.hitTest(inPoint, with: inEvent)
        
        // If the system already hit an annotation view (or something inside it), honor that.
        if let hit = systemHit {
            if hit is MKAnnotationView { return hit }
            if let superAV = hit.superview as? MKAnnotationView { return superAV }
        }
        
        // Otherwise, do our own pick among *all* annotation views that contain the tap.
        let annotationViews = _allAnnotationViews(in: self)
            .filter { !$0.isHidden && $0.alpha > 0.01 && $0.isUserInteractionEnabled }
        
        var bestView: MKAnnotationView?
        var bestDistanceSq: CGFloat = .greatestFiniteMagnitude
        
        for av in annotationViews {
            let local = av.convert(inPoint, from: self)
            
            // Respect each view’s custom hit shape/area (your AnnotationView overrides point(inside:)).
            guard av.point(inside: local, with: inEvent) else { continue }
            
            // Marker “tip” is bottom-center in the view’s local coordinates.
            let tip = CGPoint(x: av.bounds.midX, y: av.bounds.maxY)
            let dx = local.x - tip.x
            let dy = local.y - tip.y
            let distSq = dx * dx + dy * dy
            
            if distSq < bestDistanceSq {
                bestDistanceSq = distSq
                bestView = av
            }
        }
        
        // If we found an annotation view under the tap, return it so MapKit selects the right one.
        if let bestView {
            return bestView
        }
        
        // Fall back to whatever UIKit found.
        return systemHit
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
    // MARK: Special Default Marker Struct
    /* ############################################################################################################################## */
    /**
     This allows us to return a resized marker image. This is a static struct.
     */
    private struct _BJJMAssets {
        /* ############################################################## */
        /**
         The width, in display units, of our markers.
         */
        static let _sMarkerWidthInDisplayUnits: CGFloat = 24

        /* ############################################################## */
        /**
         Returns the *unresolved* asset image (keeps imageAsset variants).
         */
        static var _genericMarkerBase: UIImage { UIImage(named: "BJJM_Generic_Marker", in: ._bigJuJuMap, compatibleWith: nil) ?? UIImage() }
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
    
    /* ################################################################################################################################## */
    // MARK: - Private Popover View (Custom Callout)
    /* ################################################################################################################################## */
    /**
     */
    private final class _BJJMMarkerPopoverView: UIView, UITableViewDataSource {
        /* ############################################################################################################################## */
        //
        /* ############################################################################################################################## */
        /**
         */
        private final class _Cell: UITableViewCell {
            /* ########################################################## */
            /**
             */
            static let rowHeight: CGFloat = 28

            /* ########################################################## */
            /**
             */
            private let button: UIButton = {
                let button = UIButton(type: .system)
                button.contentHorizontalAlignment = .leading
                button.titleLabel?.numberOfLines = 1
                button.titleLabel?.lineBreakMode = .byTruncatingTail
                button.titleLabel?.adjustsFontForContentSizeCategory = true
                button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
                return button
            }()

            /* ########################################################## */
            /**
             */
            private var handler: (() -> Void)?

            /* ########################################################## */
            /**
             */
            @objc private func _tapped() { self.handler?() }

            /* ########################################################## */
            /**
             */
            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init(style: style, reuseIdentifier: reuseIdentifier)

                self.backgroundColor = .clear
                self.contentView.backgroundColor = .clear
                self.isOpaque = false
                self.selectionStyle = .none

                self.contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
                    top: 4,
                    leading: 10,
                    bottom: 4,
                    trailing: 10
                )

                self.contentView.addSubview(self.button)
                self.button.translatesAutoresizingMaskIntoConstraints = false

                let guide = self.contentView.layoutMarginsGuide
                NSLayoutConstraint.activate([
                    self.button.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
                    self.button.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                    self.button.topAnchor.constraint(equalTo: guide.topAnchor),
                    self.button.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
                ])

                self.button.addTarget(self, action: #selector(_tapped), for: .touchUpInside)
            }

            /* ########################################################## */
            /**
             */
            required init?(coder: NSCoder) { nil }

            /* ########################################################## */
            /**
             */
            func configure(title inTitle: String, handler inHandler: @escaping () -> Void) {
                self.button.setTitle(inTitle, for: .normal)
                self.handler = inHandler
            }
        }
        
        /* ################################################################## */
        /**
         */
        private static let _arrowHeight: CGFloat = 10
        
        /* ################################################################## */
        /**
         */
        private static let _arrowWidth: CGFloat = 18
        
        /* ################################################################## */
        /**
         */
        private let backgroundView: UIView = {
            let view = UIView()
            view.backgroundColor = .systemBackground
            view.layer.cornerRadius = 10
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
            return view
        }()
        
        /* ################################################################## */
        /**
         */
        private let contentInsetView = UIView()
        
        /* ################################################################## */
        /**
         */
        private let tableView: UITableView = {
            let tableView = UITableView(frame: .zero, style: .plain)
            tableView.backgroundColor = .clear
            tableView.backgroundView = nil
            tableView.isOpaque = false
            tableView.separatorStyle = .none
            tableView.showsVerticalScrollIndicator = true
            tableView.showsHorizontalScrollIndicator = false
            tableView.alwaysBounceHorizontal = false
            tableView.bounces = true
            tableView.rowHeight = _Cell.rowHeight
            tableView.estimatedRowHeight = _Cell.rowHeight
            tableView.isScrollEnabled = true
            tableView.contentInset = .zero
            tableView.scrollIndicatorInsets = .zero
            if #available(iOS 11.0, *) {
                tableView.contentInsetAdjustmentBehavior = .never
            }
            return tableView
        }()

        /* ################################################################## */
        /**
         */
        private var items: [any BigJuJuMapLocationProtocol] = []

        /* ################################################################## */
        /**
         */
        private var onSelectItem: ((any BigJuJuMapLocationProtocol) -> Void)?

        /* ################################################################## */
        /**
         */
        init() {
            super.init(frame: .zero)

            self.backgroundColor = .clear
            self.isOpaque = false

            addSubview(self.backgroundView)
            self.backgroundView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
                self.backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
                self.backgroundView.topAnchor.constraint(equalTo: topAnchor),
                self.backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            self.backgroundView.addSubview(self.contentInsetView)
            self.contentInsetView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.contentInsetView.leadingAnchor.constraint(equalTo: self.backgroundView.leadingAnchor, constant: 8),
                self.contentInsetView.trailingAnchor.constraint(equalTo: self.backgroundView.trailingAnchor, constant: -8),
                self.contentInsetView.topAnchor.constraint(equalTo: self.backgroundView.topAnchor, constant: 8),
                self.contentInsetView.bottomAnchor.constraint(equalTo: self.backgroundView.bottomAnchor, constant: -8)
            ])

            self.contentInsetView.addSubview(self.tableView)
            self.tableView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.tableView.leadingAnchor.constraint(equalTo: self.contentInsetView.leadingAnchor),
                self.tableView.trailingAnchor.constraint(equalTo: self.contentInsetView.trailingAnchor),
                self.tableView.topAnchor.constraint(equalTo: self.contentInsetView.topAnchor),
                self.tableView.bottomAnchor.constraint(equalTo: self.contentInsetView.bottomAnchor)
            ])

            self.tableView.dataSource = self
        }

        /* ################################################################## */
        /**
         */
        required init?(coder: NSCoder) { nil }

        /* ################################################################## */
        /**
         */
        func configure(items inItems: [any BigJuJuMapLocationProtocol],
                       onSelect inOnSelect: @escaping (any BigJuJuMapLocationProtocol) -> Void) {
            self.items = inItems
            self.onSelectItem = inOnSelect
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()
        }

        /* ################################################################## */
        /**
         */
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.items.count }

        /* ################################################################## */
        /**
         */
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = _Cell(style: .default, reuseIdentifier: nil)
            let item = self.items[indexPath.row]
            cell.configure(title: item.name) { [weak self] in
                self?.onSelectItem?(item)
            }
            return cell
        }

        /* ################################################################## */
        /**
         */
        func desiredWidth(maxWidth: CGFloat) -> CGFloat {
            // Best effort width: measure longest name
            let font = UIFont.preferredFont(forTextStyle: .callout)
            let padding: CGFloat = 20 // content insets inside the cell button
            let extra: CGFloat = 20   // popover breathing room

            var longest: CGFloat = 120
            self.items.forEach { inItem in
                let w = (inItem.name as NSString).size(withAttributes: [.font: font]).width
                longest = max(longest, w)
            }

            return min(maxWidth, longest + padding + extra)
        }

        /* ################################################################## */
        /**
         */
        private static let _outerPadding: CGFloat = 8   // must match the contentInsetView constraints

        /* ################################################################## */
        /**
         Full “chrome” height added outside the table rows (top + bottom padding).
         */
        private static var _verticalChrome: CGFloat { Self._outerPadding * 2 }

        /* ################################################################## */
        /**
         The ideal full height of the popover, including chrome.
         */
        var idealHeight: CGFloat {
            (CGFloat(self.items.count) * _Cell.rowHeight) + Self._verticalChrome
        }

        /* ################################################################## */
        /**
         */
        func desiredHeight(maxHeight: CGFloat) -> CGFloat {
            let full = self.idealHeight

            // Ensure a sane minimum so a single row is never clipped.
            let minimum = _Cell.rowHeight + Self._verticalChrome

            return min(maxHeight, max(minimum, full))
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
        public static let reuseID = "BJJM_AnnotationView"
        
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
            let textLayer = CATextLayer()
            textLayer.zPosition = 10_000
            textLayer.isHidden = true
            textLayer.alignmentMode = .center
            textLayer.truncationMode = .none
            textLayer.isWrapped = false
            return textLayer
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
         */
        public override func point(inside inPoint: CGPoint, with: UIEvent?) -> Bool {
            let expanded = bounds.insetBy(dx: -4, dy: -6)
            return expanded.contains(inPoint)
        }

        /* ############################################################## */
        /**
         Basic initializer.
         - parameter inAnnotation: The annotation attached to this view.
         - parameter inReuseIdentifier: The reuse ID (optional,. default is nil).
         - parameter inController: The controller that "owns" the map.
         */
        public init(annotation inAnnotation: LocationAnnotation,
                    reuseIdentifier inReuseIdentifier: String? = AnnotationView.reuseID,
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

            self.layer.addSublayer(self._countTextLayer)
            self.isEnabled = true
            self.isUserInteractionEnabled = true
            self.canShowCallout = false
        }
        
        /* ############################################################## */
        /**
         This adds our number display layer.
         */
        public required init?(coder inCoder: NSCoder) {
            super.init(coder: inCoder)
            self.layer.addSublayer(self._countTextLayer)
            self.isEnabled = true
            self.isUserInteractionEnabled = true
            self.canShowCallout = true
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

            self._countTextLayer.foregroundColor = UIColor.systemBackground.resolvedColor(with: self.traitCollection).cgColor
            
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
         
         - parameter inRect: The rectangle in which this is to be drawn.
         */
        public override func draw(_ inRect: CGRect) {
            self.image?.draw(in: inRect)
        }
        
        /* ############################################################## */
        /**
         */
        public override func didMoveToSuperview() {
            super.didMoveToSuperview()

            guard self.bounds.height > 0 else { return }

            // Center horizontally, bottom vertically
            self.centerOffset = CGPoint(
                x: 0,
                y: -self.bounds.height / 2
            )
        }
    }
    
    /* ############################################################## */
    /**
     */
    private var _activePopover: _BJJMMarkerPopoverView?

    /* ############################################################## */
    /**
     */
    private weak var _activeAnnotation: LocationAnnotation?

    /* ############################################################## */
    /**
     */
    private weak var _activeAnnotationView: MKAnnotationView?

    /* ############################################################## */
    /**
     */
    private var _dismissTapGR: UITapGestureRecognizer?
    
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
     The image to be used for markers, representing single locations.
     */
    @IBInspectable
    public var singleMarkerImage: UIImage?

    /* ################################################################## */
    /**
     The image to be used for markers, representing aggregated locations.
     */
    @IBInspectable
    public var multiMarkerImage: UIImage?

    /* ################################################################## */
    /**
     If true, multiple (aggregate) markers will display the number of elements aggregated. Default is true.
     */
    @IBInspectable
    public var displayNumbers = true
}

/* ################################################################################################################################## */
// MARK: Private Computed Properties
/* ################################################################################################################################## */
private extension BigJuJuMapViewController {
    /* ################################################################## */
    /**
     This creates annotations for the meeting search results.
     
     - returns: An array of annotations (may be empty).
     */
    var _myAnnotations: [LocationAnnotation] { self._clusterAnnotations(self.mapData.map { LocationAnnotation($0) }) }
}

/* ################################################################################################################################## */
// MARK: Public Computed Properties
/* ################################################################################################################################## */
public extension BigJuJuMapViewController {
    /* ################################################################## */
    /**
     The main view of this controller is a map. This simply casts that.
     
     > NOTE: This does an implicit unwrap, because we are in deep poo, if it fails.
     */
    var mapView: MKMapView { self.view as! MKMapView }
}

/* ################################################################################################################################## */
// MARK: Private Instance Methods
/* ################################################################################################################################## */
extension BigJuJuMapViewController {
    /* ############################################################## */
    /**
     */
    @MainActor
    private func _dismissPopover() {
        self._activePopover?.removeFromSuperview()
        self._activePopover = nil
        self._activeAnnotation = nil
        self._activeAnnotationView = nil
    }

    /* ############################################################## */
    /**
     */
    @MainActor
    private func _installDismissTapIfNeeded() {
        guard self._dismissTapGR == nil else { return }

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(_didTapMapToDismiss))
        gestureRecognizer.cancelsTouchesInView = false
        gestureRecognizer.delegate = self
        self.mapView.addGestureRecognizer(gestureRecognizer)
        self._dismissTapGR = gestureRecognizer
    }
    
    /* ############################################################## */
    /**
     */
    @objc @MainActor
    private func _didTapMapToDismiss() {
        self._dismissPopover()
    }

    /* ############################################################## */
    /**
     */
    @MainActor
    private func _positionPopover(_ inPopover: _BJJMMarkerPopoverView, for inView: MKAnnotationView) {
        let safe = self.mapView.safeAreaInsets
        let padding: CGFloat = 10

        // Available width
        let maxWidth = self.mapView.bounds.width - (safe.left + safe.right) - 2 * padding
        let width = inPopover.desiredWidth(maxWidth: maxWidth)

        // Available height (prefer above the marker if possible)
        let markerFrame = inView.frame

        let availableAbove = markerFrame.minY - safe.top - padding
        let availableBelow = self.mapView.bounds.height - safe.bottom - markerFrame.maxY - padding

        // How tall would the whole list be?
        let idealListHeight = inPopover.idealHeight
        
        // Choose above if it fits better; else below.
        let showAbove = availableAbove >= min(idealListHeight, 200) || availableAbove >= availableBelow
        let maxHeight = max(60, showAbove ? availableAbove : availableBelow)
        let height = inPopover.desiredHeight(maxHeight: min(maxHeight, self.mapView.bounds.height * 0.5))

        // Center horizontally on marker, clamp to safe bounds
        var x = markerFrame.midX - (width * 0.5)
        x = max(padding + safe.left, min(x, self.mapView.bounds.width - safe.right - padding - width))

        let y: CGFloat
        if showAbove {
            y = markerFrame.minY - padding - height
        } else {
            y = markerFrame.maxY + padding
        }

        inPopover.frame = CGRect(x: x, y: y, width: width, height: height)
    }

    /* ################################################################## */
    /**
     Returns the opposite of the current UI style.
     */
    private func _reversedStyle(for inStyle: UIUserInterfaceStyle) -> UIUserInterfaceStyle {
        switch inStyle {
        case .dark:
            return .light
        case .light:
            return .dark
        default:
            return .unspecified
        }
    }
    
    /* ################################################################## */
    /**
     Apply the correct marker image to the given annotation view, optionally forcing
     the marker to resolve in the *opposite* trait mode.
     */
    @MainActor
    private func _applyMarkerAppearance(to inView: MKAnnotationView, reversed: Bool) {
        guard let annotation = inView.annotation as? LocationAnnotation else { return }

        let count = annotation.data.count
        let base = (count == 1) ? self.singleMarkerImage : self.multiMarkerImage

        if reversed {
            let reversedStyle = _reversedStyle(for: self.traitCollection.userInterfaceStyle)

            // Force the view itself to render in reversed style.
            inView.overrideUserInterfaceStyle = reversedStyle

            // Build traits that include the reversed userInterfaceStyle, so the image asset resolves correctly.
            let reversedTraits = UITraitCollection(traitsFrom: [
                self.traitCollection,
                UITraitCollection(userInterfaceStyle: reversedStyle)
            ])

            inView.image = self._markerImage(from: base, compatibleWith: reversedTraits)
        } else {
            // Back to normal.
            inView.overrideUserInterfaceStyle = .unspecified
            inView.image = self._markerImage(from: base, compatibleWith: self.traitCollection)
        }

        // If it’s your custom view, relayout so the count layer refreshes.
        (inView as? AnnotationView)?.setNeedsLayout()
    }
    
    /* ################################################################## */
    /**
     This returns a marker image that will change when the markers are recalculated.
     - parameter inBase: The image that we resize (the original asset).
     - parameter inTraits: The traits style (light or dark) that we want.
     - returns: A scaled, appropriate marker image.
     */
    private func _markerImage(from inBase: UIImage?, compatibleWith inTraits: UITraitCollection) -> UIImage {
        let base = inBase ?? _BJJMAssets._genericMarkerBase
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
              !self.mapView.bounds.isEmpty,
              8 < _BJJMAssets._sMarkerWidthInDisplayUnits
        else { return [] }
        
        // Cluster size in screen points.
        let cellSize = _BJJMAssets._sMarkerWidthInDisplayUnits
        
        // We store the cluster annotation and an approximate screen-center for neighbor checks.
        var clusters: [_CellKey: LocationAnnotation] = [:]
        var centers: [_CellKey: CGPoint] = [:]
        
        inAnnotations.forEach { inAnnotation in
            let point = self.mapView.convert(inAnnotation.coordinate, toPointTo: self.mapView)
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
                existing.data.append(contentsOf: inAnnotation.data)
                
                // Update stored screen center (simple running average by item-count).
                let oldCenter = centers[useKey] ?? point
                let oldCount = max(1, existing.data.count - inAnnotation.data.count)
                let newCount = existing.data.count
                let total = CGFloat(oldCount) / CGFloat(newCount)
                centers[useKey] = CGPoint(
                    x: oldCenter.x * total + point.x * (1 - total),
                    y: oldCenter.y * total + point.y * (1 - total)
                )
            } else {
                clusters[useKey] = inAnnotation
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
        self.view = _BJJMMapView()
        self.mapView.delegate = self

        if #available(iOS 17.0, *) {
            self.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
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

        guard let inPreviousTraitCollection,
              self.traitCollection.hasDifferentColorAppearance(comparedTo: inPreviousTraitCollection)
        else { return }

        self._recalculateAnnotations()
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
     
     - parameter inMapView: The map view being rendered (ignored).
     - parameter fullyRendered: Ignored.
     */
    @MainActor
    public func mapViewDidFinishRenderingMap(_ inMapView: MKMapView, fullyRendered: Bool) {
        self._recalculateAnnotations()
    }
    
    /* ################################################################## */
    /**
     Called when the map has changed its region. We use it to force the annotations to be recalculated.
     
     - parameter inMapView: The map view being rendered (ignored).
     - parameter regionDidChangeAnimated: Ignored.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView, regionDidChangeAnimated: Bool) {
        if let popover = self._activePopover,
           let view = self._activeAnnotationView {
            self._positionPopover(popover, for: view)
        }
        
        if self._activePopover == nil {
            self._recalculateAnnotations()
        }
    }
    
    /* ################################################################## */
    /**
     This is called when a marker is selected.
     
     - parameter inMapView: The map view
     - parameter inView: The marker we're selecting.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView, didSelect inView: MKAnnotationView) {
        guard let annotation = inView.annotation as? LocationAnnotation else { return }
        
        // Don’t show for user location
        if annotation.isKind(of: MKUserLocation.self) {
            inMapView.deselectAnnotation(annotation, animated: false)
            return
        }
        
        self._applyMarkerAppearance(to: inView, reversed: true)
        
        self._dismissPopover()
        self._installDismissTapIfNeeded()
        
        self._activeAnnotation = annotation
        self._activeAnnotationView = inView
        
        let popover = _BJJMMarkerPopoverView()
        self._activePopover = popover
        
        popover.configure(items: annotation.data) { [weak self] item in
            guard let self else { return }
            self._dismissPopover()
            inMapView.deselectAnnotation(annotation, animated: true)
            item.callHandler()
        }
        
        inMapView.addSubview(popover)
        self._positionPopover(popover, for: inView)
    }
    
    /* ################################################################## */
    /**
     This is called when a marker is deselected.
     
     - parameter inMapView: The map view
     - parameter inView: The marker we're deselecting.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView, didDeselect inView: MKAnnotationView) {
        if inView === self._activeAnnotationView {
            self._dismissPopover()
        }
        
        self._applyMarkerAppearance(to: inView, reversed: false)
    }
}

/* ################################################################################################################################## */
// MARK: UIGestureRecognizerDelegate Conformance
/* ################################################################################################################################## */
extension BigJuJuMapViewController: UIGestureRecognizerDelegate {
    /* ################################################################## */
    /**
     Called to determine whether or not to consume a touch event.
     
     - parameter inGestureRecognizer: The gesture recognizer(ignored)
     - parameter inTouch: The touch event
     - returns: True, if the touch event is valid.
     */
    public func gestureRecognizer(_ inGestureRecognizer: UIGestureRecognizer, shouldReceive inTouch: UITouch) -> Bool {
        guard let popover = self._activePopover,
           inTouch.view?.isDescendant(of: popover) == true
        else { return true }
        
        return false
    }
}
