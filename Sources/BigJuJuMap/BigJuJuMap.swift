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
 
 Version: 1.1.7
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
// MARK: - Private Bundle Extension, to Get the Framework/Package Bundle -
/* ################################################################################################################################## */
private extension Bundle {
    /* ################################################################## */
    /**
     Find the bundle that contains BigJuJuMap resources (Media.xcassets, etc.)
     
     - If built as a Swift Package: uses SwiftPM’s resource bundle (`Bundle.module`)
     - Otherwise (directly included in an app/framework target): uses the containing binary bundle
     */
    static var _bigJuJuMap: Bundle {
        #if SWIFT_PACKAGE
            return .module
        #else
            return Bundle(for: _BJJMBundleToken.self)
        #endif
    }
}

/* ################################################################################################################################## */
// MARK: - Private UIImage Extension, to Add Simple Resizing Function -
/* ################################################################################################################################## */
private extension UIImage {
    /* ################################################################## */
    /**
     This rescales a UIImage, to fit a given width, preserving the aspect.
     
     - parameter inTargetWidth: The width we want the resulting image to be, in display units.
     - returns: A new, rescaled, UIImage, made from this UIImage
     */
    func _scaledToWidth(_ inTargetWidth: CGFloat) -> UIImage {
        guard inTargetWidth > 0,
              self.size.width > 0,
              self.size.height > 0
        else { return self }

        let scaleFactor = inTargetWidth / self.size.width
        let targetSize = CGSize(width: inTargetWidth,
                                height: self.size.height * scaleFactor
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale   // preserves retina scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize,
                                       format: format
        ).image { _ in
            self.draw(in: CGRect(origin: .zero,
                                 size: targetSize
                                )
            )
        }
    }
}

/* ################################################################################################################################## */
// MARK: Big Map View Controller Class
/* ################################################################################################################################## */
/**
 This is the heart of this package.
 
 It is a UIViewController, with a single, full-fill MKMapView. That view will have markers, designating the data provided.
 
 Selecting a marker, will pop up a callout, with the data item name. If it is an aggregate annotation, then the callout will contain a list.
 
 Selecting an item in the list, will trigger the `callHandler()` function, associated with that annotation, and the handler will be called (should be in the main thread, but that can be changed, by giving a threaded handler).
 
 The map can display different markers, if ones are provided. Otherwise, it will use the default (simple "upside-down teardrop") markers.
 
 In the case of aggregate (multi) markers, the map can draw the number of contained data items, over the marker. This can be disabled.
 
 Selecting a marker will display a simple "popover" over (or under) the selected marker. This will have a list of the data items associated with that marker.
 
 Selecting an item will call a handler, with that item as its input argument.
 */
@IBDesignable
open class BigJuJuMapViewController: UIViewController {
    /* ############################################################################################################################## */
    // MARK: Private MKMapView Subclass for Deterministic Annotation Hit-Testing
    /* ############################################################################################################################## */
    /**
     This allows us to pick the marker best suited for a hit-test, when they are piled together.
     */
    private final class _BJJMMapView: MKMapView {
        /* ############################################################## */
        /**
         Recursively collect all MKAnnotationView instances in the view hierarchy.
         
         - parameter inView: The view conmtaining annotations.
         - returns: A list of annotations for the view.
         */
        private func _allAnnotationViews(in inView: UIView) -> [MKAnnotationView] {
            var ret: [MKAnnotationView] = []
            
            if let av = inView as? MKAnnotationView {
                ret.append(av)
            }
            
            for sub in inView.subviews {
                ret.append(contentsOf: self._allAnnotationViews(in: sub))
            }
            
            return ret
        }
        
        /* ############################################################## */
        /**
         This returns the deepest viable control (not just a view), in the view hiearchy begun by the input root view.
         
         - parameter inRootView: The "container" for the hierarchy.
         - parameter inPointInRoot: The point, in the root view coordinate system, to test.
         - returns: Any UIControl under that point.
         */
        private func _deepestControl(in inRootView: UIView,
                                     at inPointInRoot: CGPoint
        ) -> UIControl? {
            for subView in inRootView.subviews.reversed() where !subView.isHidden && subView.alpha > 0.01 && subView.isUserInteractionEnabled {
                let point = subView.convert(inPointInRoot,
                                            from: inRootView
                )
                guard subView.bounds.contains(point) else { continue }

                if let control = subView as? UIControl {
                    return control
                }
                
                if let found = self._deepestControl(in: subView,
                                                    at: point
                ) {
                    return found
                }
            }
            return nil
        }
        
        /* ############################################################## */
        /**
         Overrides hit-testing so that, when multiple annotation views overlap,
         we deterministically pick the annotation whose tip (bottom-center) is closest to the tap.
         > NOTE: All markers are assumed to have their tip at the bottom, center of the image.
         
         - parameter inPoint: The point being tested.
         - parameter inEvent: The event providing the hit.
         - returns: The view that is being selected.
         */
        override func hitTest(_ inPoint: CGPoint,
                              with inEvent: UIEvent?
        ) -> UIView? {
            func ancestor<T: UIView>(of view: UIView,
                                     as type: T.Type
            ) -> T? {
                var viewTemp: UIView? = view
                while let current = viewTemp {
                    if let match = current as? T {
                        return match
                    }
                    viewTemp = current.superview
                }
                return nil
            }

            let systemHit = super.hitTest(inPoint,
                                          with: inEvent
            )

            if let hit = systemHit {
                // If the tap is anywhere inside a table/callout subtree, try to pull out the actual UIControl.
                // (UITableViewCellContentView often gets returned even when the button is visually there.)
                let local = hit.convert(inPoint,
                                        from: self
                )
                if let control = _deepestControl(in: hit,
                                                 at: local
                ) {
                    return control
                }

                // If it’s inside a UITableView, at least honor that subtree.
                if ancestor(of: hit,
                            as: UITableView.self
                ) != nil { return hit }

                // If it’s inside an annotation view/callout, return the annotation view (marker taps).
                if let daddy = ancestor(of: hit,
                                        as: MKAnnotationView.self
                ) { return daddy }

                if hit !== self { return hit }
            }
            
            // If UIKit hit some other subview (not the map itself), honor it.
            if let hit = systemHit,
               hit !== self {
                return hit
            }
            
            // Otherwise, do our “best marker under finger” selection (for piled markers).
            let annotationViews = self._allAnnotationViews(in: self).filter { !$0.isHidden && $0.alpha > 0.01 && $0.isUserInteractionEnabled }
            
            var bestView: MKAnnotationView?
            var bestDistanceSq: CGFloat = .greatestFiniteMagnitude
            
            for annotationView in annotationViews {
                let local = annotationView.convert(inPoint,
                                                   from: self
                )
                
                guard annotationView.point(inside: local,
                                           with: inEvent
                )
                else { continue }
                
                let markerPoint = CGPoint(x: annotationView.bounds.midX,
                                          y: annotationView.bounds.maxY
                )
                let deltaX = local.x - markerPoint.x
                let deltaY = local.y - markerPoint.y
                let distSq = deltaX * deltaX + deltaY * deltaY
                
                if distSq < bestDistanceSq {
                    bestDistanceSq = distSq
                    bestView = annotationView
                }
            }
            
            return bestView
        }
    }

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
         Returns the unresolved asset image (keeps imageAsset variants).
         */
        static var _genericMarkerBase: UIImage { UIImage(named: "BJJM_Generic_Marker",
                                                         in: ._bigJuJuMap,
                                                         compatibleWith: nil
        ) ?? UIImage()
        }
    }
    
    /* ############################################################################################################################## */
    // MARK: Custom Annotation Class
    /* ############################################################################################################################## */
    /**
     This is used to denote a single annotation item
     */
    public class LocationAnnotation: NSObject, MKAnnotation {
        /* ########################################################## */
        /**
         The coordinate of this annotation
         */
        public private(set) var coordinate: CLLocationCoordinate2D

        /* ########################################################## */
        /**
         The data associated with this annotation
         */
        public var data: [any BigJuJuMapLocationProtocol]

        /* ########################################################## */
        /**
         Latitude summation
         */
        private var _latSum: Double

        /* ########################################################## */
        /**
         Longitude summation.
         */
        private var _lonSum: Double

        /* ########################################################## */
        /**
         This merges annotations, in an efficient manner.
         
         - parameter inToBeMerged: The annotation with the data to be merged into this annotation.
         */
        fileprivate func _mergeIn(_ inToBeMerged: LocationAnnotation) {
            self.data.append(contentsOf: inToBeMerged.data)
            self._latSum += inToBeMerged._latSum
            self._lonSum += inToBeMerged._lonSum
            let count = Double(max(1,
                                   self.data.count
                                  )
            )
            
            self.coordinate = CLLocationCoordinate2D(latitude: _latSum / count,
                                                     longitude: _lonSum / count
            )
        }

        /* ########################################################## */
        /**
         Initializer with an array of location data entities.
         
         - parameter inData: An array of data items, conformant to BigJuJuMapLocationProtocol
         */
        public init(_ inData: [any BigJuJuMapLocationProtocol]) {
            self.data = inData

            var lat = 0.0
            var lon = 0.0
            for item in inData {
                lat += item.location.coordinate.latitude
                lon += item.location.coordinate.longitude
            }
            
            self._latSum = lat
            self._lonSum = lon

            let c = max(1,
                        inData.count
            )
            
            self.coordinate = CLLocationCoordinate2D(latitude: lat / Double(c),
                                                     longitude: lon / Double(c)
            )
        }

        /* ########################################################## */
        /**
         Initializer with a single location data entity.
         
         - parameter inData: A single data item, conformant to BigJuJuMapLocationProtocol
         */
        public convenience init(_ inData: any BigJuJuMapLocationProtocol) { self.init([inData]) }
    }
    
    /* ################################################################################################################################## */
    // MARK: Private Popover View (Custom Callout)
    /* ################################################################################################################################## */
    /**
     This is a "popover" that we construct from whole cloth, to present a table with all of the annotation data items.
     */
    private class _BJJMMarkerPopoverView: UIView, UITableViewDataSource, UITableViewDelegate {
        /* ############################################################################################################################## */
        // MARK: A Single Cell (Row) in the Table
        /* ############################################################################################################################## */
        /**
         This simply allows us to have custom properties in our cells.
         */
        private final class _Cell: UITableViewCell {
            /* ########################################################## */
            /**
             The height, in display units, of one row of the table.
             */
            static let rowHeight: CGFloat = 28

            /* ########################################################## */
            /**
             Each row is actually an inoperative button, selecting the handler for the data entity attached to the row.
             */
            let button: UIButton = {
                let button = UIButton(type: .system)
                button.contentHorizontalAlignment = .leading
                button.titleLabel?.numberOfLines = 1
                button.titleLabel?.lineBreakMode = .byTruncatingTail
                button.titleLabel?.adjustsFontForContentSizeCategory = true
                button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
                button.isUserInteractionEnabled = false
                return button
            }()

            /* ########################################################## */
            /**
             Whenever we assign a new data item, we set the button name.
             */
            var locationData: (any BigJuJuMapLocationProtocol)? { didSet { self.button.setTitle(self.locationData?.name ?? "ERROR", for: .normal) } }

            /* ########################################################## */
            /**
             Basic initializer.
             
             - parameter inStyle: The button style.
             - parameter inReuseID: The reuse identifier.
             */
            override init(style inStyle: UITableViewCell.CellStyle,
                          reuseIdentifier inReuseID: String?
            ) {
                super.init(style: inStyle,
                           reuseIdentifier: inReuseID
                )

                self.backgroundColor = .clear
                self.contentView.backgroundColor = .clear
                self.isOpaque = false
                self.selectionStyle = .none

                self.contentView.addSubview(self.button)
                self.button.translatesAutoresizingMaskIntoConstraints = false

                NSLayoutConstraint.activate([
                    self.button.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor,
                                                         constant: 10
                                                        ),
                    self.button.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor,
                                                          constant: -10
                                                         ),
                    self.button.topAnchor.constraint(equalTo: self.contentView.topAnchor,
                                                     constant: 4
                                                    ),
                    self.button.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor,
                                                        constant: -4
                                                       )
                ])
            }

            /* ########################################################## */
            /**
             Required for coder compliance.
             
             - parameter coder: ignored.
             */
            required init?(coder: NSCoder) { nil }
        }

        /* ################################################################## */
        /**
         The curve of the window.
         */
        private static let _cornerRadiusInDisplayUnits = CGFloat(10)

        /* ################################################################## */
        /**
         Padding for the table items.
         */
        private static let _paddingInDisplayUnits = CGFloat(20)

        /* ################################################################## */
        /**
         Insets for the table items.
         */
        private static let _insetsInDisplayUnits = CGFloat(16)

        /* ################################################################## */
        /**
         The maximum width of display items.
         */
        private static let _maxItemWidthInDisplayUnits = CGFloat(120)

        /* ################################################################## */
        /**
         This is the padding inside the cell.
         */
        private static let _outerPadding: CGFloat = 8

        /* ################################################################## */
        /**
         Full “chrome” height added outside the table rows (top + bottom padding).
         */
        private static var _verticalChrome: CGFloat { Self._outerPadding * 2 }

        /* ################################################################## */
        /**
         This is the background view for the popover window.
         */
        private let backgroundView: UIView = {
            let view = UIView()
            view.backgroundColor = .systemBackground
            view.layer.cornerRadius = _BJJMMarkerPopoverView._cornerRadiusInDisplayUnits
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
            return view
        }()
        
        /* ################################################################## */
        /**
         The view that contains the table content (we inset it).
         */
        private let contentInsetView = UIView()
        
        /* ################################################################## */
        /**
         This is the table view that we use to display the data items.
         */
        private let tableView: UITableView = {
            let tableView = UITableView(frame: .zero,
                                        style: .plain
            )
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
            tableView.contentInsetAdjustmentBehavior = .never
            return tableView
        }()

        /* ################################################################## */
        /**
         These are all the items to be displayed in the table.
         */
        private var items: [any BigJuJuMapLocationProtocol] = []

        /* ################################################################## */
        /**
         The signature of the closure for handling item selection, in the table.
         */
        private var onSelectItem: ((any BigJuJuMapLocationProtocol) -> Void)?

        /* ################################################################## */
        /**
         The content size that we want for our popover.
         */
        override var intrinsicContentSize: CGSize {
            let height = self.tableView.contentSize.height + Self._insetsInDisplayUnits
            let width  = self.tableView.contentSize.width  + Self._insetsInDisplayUnits
            return CGSize(width: max(Self._maxItemWidthInDisplayUnits,
                                     width
                                    ),
                          height: max(self.tableView.rowHeight,
                                      height
                                     )
            )
        }

        /* ################################################################## */
        /**
         Standard initializer.
         We use this to build our table.
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
                self.contentInsetView.leadingAnchor.constraint(equalTo: self.backgroundView.leadingAnchor,
                                                               constant: Self._outerPadding
                                                              ),
                self.contentInsetView.trailingAnchor.constraint(equalTo: self.backgroundView.trailingAnchor,
                                                                constant: -Self._outerPadding
                                                               ),
                self.contentInsetView.topAnchor.constraint(equalTo: self.backgroundView.topAnchor,
                                                           constant: Self._outerPadding
                                                          ),
                self.contentInsetView.bottomAnchor.constraint(equalTo: self.backgroundView.bottomAnchor,
                                                              constant: -Self._outerPadding
                                                             )
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
            self.tableView.delegate = self
            self.tableView.allowsSelection = true
        }

        /* ################################################################## */
        /**
         Required for coder compliance.
         
         - parameter coder: ignored.
         */
        required init?(coder: NSCoder) { nil }

        // MARK: Published API
        
        /* ################################################################## */
        /**
         The desired width of the popover, adjusted for content.
         
         - parameter inMaxWidth: The maximum width, in display units, of the popover.
         - parameter inFont: If provided (optional, default is nil), a font to use for calculations.
         - returns: The width, in display units, that we want our popover to be.
         */
        func desiredWidth(maxWidth inMaxWidth: CGFloat,
                          withFont inFont: UIFont? = nil
        ) -> CGFloat {
            // Best effort width: measure longest name
            let font = inFont ?? UIFont.preferredFont(forTextStyle: .callout)
            let padding: CGFloat = Self._paddingInDisplayUnits // content insets inside the cell button
            let extra: CGFloat = Self._paddingInDisplayUnits   // popover breathing room

            var longest: CGFloat = Self._maxItemWidthInDisplayUnits
            self.items.forEach { inItem in
                let w = (inItem.name as NSString).size(withAttributes: [.font: font]).width
                longest = max(longest, w)
            }

            return min(inMaxWidth, longest + padding + extra)
        }

        /* ################################################################## */
        /**
         The desired height of the popover, adjusted for content.
         
         - parameter inMaxHeight: The maximum width, in display units, of the popover. (Optional, default is max float).
         - parameter inFont: If provided (optional, default is nil), a font to use for calculations.
         - returns: The height, in display units, that we want our popover to be.
         */
        @MainActor
        func desiredHeight(maxHeight inMaxHeight: CGFloat = .greatestFiniteMagnitude,
                           withFont inFont: UIFont? = nil
        ) -> CGFloat {
            let rowHeight = ceil(inFont?.lineHeight ?? _Cell.rowHeight)
            let full = ceil(CGFloat(items.count) * rowHeight + (Self._verticalChrome * 1.2))
            let minimum = ceil(rowHeight + Self._verticalChrome)
            return min(inMaxHeight,
                       max(minimum,
                           full
                          )
            )
        }

        /* ################################################################## */
        /**
         This is used to set up the popover to whatever the data looks like.
         
         - parameter inItems: The data associated with the annotation calling the popover.
         - parameter inOnSelect: The selection closure.
         */
        func configure(items inItems: [any BigJuJuMapLocationProtocol],
                       onSelect inOnSelect: @escaping (any BigJuJuMapLocationProtocol) -> Void
        ) {
            self.items = inItems
            self.onSelectItem = inOnSelect
            self.tableView.reloadData()
        }

        // MARK: UITableViewDelegate Conformance
        
        /* ########################################################## */
        /**
         Called when a table row is selected.
         
         - parameter inTableView: The table view with the row being selected.
         - parameter inIndexPath: The index path of the row being selected.
         */
        func tableView(_ inTableView: UITableView,
                       didSelectRowAt inIndexPath: IndexPath
        ) {
            inTableView.deselectRow(at: inIndexPath, animated: true)
            guard inIndexPath.row < self.items.count else { return }
            let item = self.items[inIndexPath.row]
            self.onSelectItem?(item)
        }

        // MARK: UITableViewDataSource Conformance

        /* ################################################################## */
        /**
         Returns the number of rows to display in the table.
         
         - parameter inTableView: The table view with the row being selected (ignored).
         - parameter numberOfRowsInSection: ignored
         - returns: The number of data items in the associated annotation.
         */
        func tableView(_ inTableView: UITableView,
                       numberOfRowsInSection: Int
        ) -> Int { self.items.count }

        /* ################################################################## */
        /**
         Creates a table cell
         
         - parameter inTableView: The table view with the row being created (ignored).
         - parameter inIndexPath: The index path of the row being created.
         - returns: A new custom table cell, associated with a data item.
         */
        func tableView(_ inTableView: UITableView,
                       cellForRowAt inIndexPath: IndexPath
        ) -> UITableViewCell {
            let cell = _Cell(style: .default,
                             reuseIdentifier: nil
            )
            let item = self.items[inIndexPath.row]
            cell.locationData = item
            cell.selectionStyle = .none
            
            if let textColor = item.textColor {
                cell.button.setTitleColor(textColor,
                                          for: .normal
                )
            }
            
            if let textFont = item.textFont {
                cell.button.titleLabel?.font = textFont
            }
            
            return cell
        }
    }

    /* ############################################################################################################################## */
    // MARK: Custom Annotation View Class
    /* ############################################################################################################################## */
    /**
     This is used to display a map marker.
     */
    public class AnnotationView: MKAnnotationView {
        /* ############################################################## */
        /**
         The reuse ID for these annotations.
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
            guard inRect.width > 1,
                  inRect.height > 1
            else { return inMinFontSize }

            /* ########################################################## */
            /**
             Test to see if the shoe fits.
             
             - returns: True, if the size fits the string.
             */
            func _fits(_ inSize: CGFloat) -> Bool {
                let font = UIFont.systemFont(ofSize: inSize,
                                             weight: inWeight
                )
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
         This returns a text layer, for the number of aggregate data points.
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
         This tests whether or not the given point fits inside the annotation.
         
         - parameter inPoint: The point to test
         - parameter with: ignored.
         - returns: True, if the point is within the annotation.
         */
        public override func point(inside inPoint: CGPoint,
                                   with: UIEvent?
        ) -> Bool {
            let expanded = self.bounds.insetBy(dx: -4,
                                               dy: -6
            )
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
            super.init(annotation: inAnnotation,
                       reuseIdentifier: inReuseIdentifier
            )
            self.myController = inController
            let isSingle = (self.myAnnotation?.data.count ?? 0) == 1
            let base = isSingle ? inController?.singleMarkerImage : inController?.multiMarkerImage

            if let controller = inController {
                self.image = controller._markerImage(from: base,
                                                     compatibleWith: controller.traitCollection
                )
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

            self._countTextLayer.contentsScale = window?.windowScene?.screen.scale ?? traitCollection.displayScale

            let count = self.myAnnotation?.data.count ?? 0
            let show = (self.myController?.displayNumbers ?? false) && count > 1

            self._countTextLayer.isHidden = !show
            guard show else { return }

            let rect = bounds
            let drawBox = CGRect(
                x: 2,
                y: 4,
                width: rect.width - 4,
                height: rect.height * 0.45
            )

            let text = "\(count)"
            self._countTextLayer.string = text

            self._countTextLayer.foregroundColor = UIColor.systemBackground.resolvedColor(with: self.traitCollection).cgColor
            
            let maxFontSize = max(6,
                                  drawBox.height
            )

            let fitted = Self._bestFittingFontSize(
                for: text,
                in: drawBox,
                maxFontSize: maxFontSize,
                minFontSize: 6,
                weight: .bold
            )

            let font = UIFont.systemFont(ofSize: fitted,
                                         weight: .bold
            )
            
            self._countTextLayer.font = font
            self._countTextLayer.fontSize = fitted

            let yOffset = max(0,
                              (drawBox.height - font.lineHeight) * 0.5
            )
            
            self._countTextLayer.frame = drawBox.offsetBy(dx: 0,
                                                          dy: yOffset
            )
        }
        
        /* ############################################################## */
        /**
         Called when the view is transitioned within the hierarchy.
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
     Any active popover.
     */
    private var _activePopover: _BJJMMarkerPopoverView?

    /* ############################################################## */
    /**
     The currently selected annotation.
     */
    private weak var _activeAnnotation: LocationAnnotation?

    /* ############################################################## */
    /**
     The view for the currently selected annotation.
     */
    private weak var _activeAnnotationView: MKAnnotationView?

    /* ############################################################## */
    /**
     A gesture reconzier that is used to dismiss the popover.
     */
    private var _dismissTapGR: UITapGestureRecognizer?
    
    /* ############################################################## */
    /**
     This prevents the marker from rectivating, when tapped while active.
     */
    private var _ignoreNextSelectAnnotation: LocationAnnotation?
    
    // MARK: PUBLIC PROPERTIES
    
    /* ################################################################## */
    /**
     The data for the map to display.
     
     Each item will be displayed in a marker. Markers may be aggregated.
     */
    public var mapData: [any BigJuJuMapLocationProtocol] = [] { didSet { DispatchQueue.main.async { self._recalculateAnnotations() } } }
    
    /* ################################################################## */
    /**
     The image to be used for markers, representing single locations. Default is the generic map marker (both single and aggregate)
     */
    @IBInspectable
    public var singleMarkerImage: UIImage? { didSet {
        if oldValue == self.singleMarkerImage { return }
        DispatchQueue.main.async { self._recalculateAnnotations() } }
    }

    /* ################################################################## */
    /**
     The image to be used for markers, representing aggregated locations. Default is the generic map marker (both single and aggregate)
     */
    @IBInspectable
    public var multiMarkerImage: UIImage? { didSet {
        if oldValue == self.multiMarkerImage { return }
        DispatchQueue.main.async { self._recalculateAnnotations() } }
    }

    /* ################################################################## */
    /**
     If true, multiple (aggregate) markers will display the number of elements aggregated. Default is true.
     */
    @IBInspectable
    public var displayNumbers = true { didSet {
        if oldValue == self.displayNumbers { return }
        DispatchQueue.main.async { self._recalculateAnnotations() } }
    }

    /* ################################################################## */
    /**
     If true (default is false), then popovers will not dismiss, when an item is selected.
     */
    @IBInspectable
    public var stickyPopups = false
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
    
    /* ################################################################## */
    /**
     This allows direct access to the displayed map region.
     */
    var region: MKCoordinateRegion {
        get { self.mapView.region }
        set { self.mapView.setRegion(newValue,
                                     animated: true
        ) }
    }
    
    /* ################################################################## */
    /**
     This allows direct access to the displayed map rect.
     */
    var visibleRect: MKMapRect {
        get { self.mapView.visibleMapRect }
        set { self.mapView.setVisibleMapRect(newValue,
                                             edgePadding: .zero,
                                             animated: true
        ) }
    }
}

/* ################################################################################################################################## */
// MARK: Private Instance Methods
/* ################################################################################################################################## */
extension BigJuJuMapViewController {
    /* ############################################################## */
    /**
     Called to close the popover.
     */
    @MainActor
    private func _dismissPopover() {
        if let popover = self._activePopover {
            self._activePopover = nil
            popover.removeFromSuperview()
        }
        
        if let activeAnnotationView = self._activeAnnotationView {
            self._activeAnnotationView = nil
            self._applyMarkerAppearance(to: activeAnnotationView,
                                        reversed: false
            )
        }

        if let activeAnnotation = self._activeAnnotation {
            self._activeAnnotation = nil
            self.mapView.deselectAnnotation(activeAnnotation,
                                            animated: true
            )
        }
    }

    /* ############################################################## */
    /**
     Installs the background dismiss tapper
     */
    @MainActor
    private func _installDismissTapIfNeeded() {
        guard self._dismissTapGR == nil else { return }

        let gestureRecognizer = UITapGestureRecognizer(target: self,
                                                       action: #selector(_didTapMapToDismiss)
        )
        
        gestureRecognizer.cancelsTouchesInView = false
        gestureRecognizer.delegate = self
        
        self.mapView.addGestureRecognizer(gestureRecognizer)
        self._dismissTapGR = gestureRecognizer
    }
    
    /* ############################################################## */
    /**
     Called when the background is tapped.
     */
    @objc @MainActor
    private func _didTapMapToDismiss() {
        // If this dismiss tap happened on the currently active marker, ignore the very next didSelect for it.
        if let tap = self._dismissTapGR,
           let activeView = self._activeAnnotationView,
           let activeAnnotation = self._activeAnnotation {
            let point = tap.location(in: self.mapView)

            // A small inset helps if the marker view has transparent padding.
            if activeView.frame.insetBy(dx: -8,
                                        dy: -8
            ).contains(point) {
                self._ignoreNextSelectAnnotation = activeAnnotation
            }
        }

        self._dismissPopover()
    }
    
    /* ############################################################## */
    /**
     This makes sure the popover is positioned near the selected marker.
     
     - parameter inPopover: The popover view.
     - parameter inView: The annotation view we're being displayed near.
     */
    @MainActor
    private func _positionPopover(_ inPopover: _BJJMMarkerPopoverView,
                                  for inView: MKAnnotationView
    ) {
        let font = (inView as? AnnotationView)?.myAnnotation?.data.first?.textFont
        let safe = self.mapView.safeAreaInsets
        let padding: CGFloat = 10

        // Available width
        let maxWidth = self.mapView.bounds.width - (safe.left + safe.right) - 2 * padding
        let width = inPopover.desiredWidth(maxWidth: maxWidth,
                                           withFont: font
        )

        // Available height (prefer above the marker if possible)
        let markerFrame = inView.frame

        let availableAbove = markerFrame.minY - safe.top - padding
        let availableBelow = self.mapView.bounds.height - safe.bottom - markerFrame.maxY - padding

        // How tall would the whole list be?
        let idealListHeight = inPopover.desiredHeight(withFont: font)
        
        // Choose above if it fits better; else below.
        let showAbove = availableAbove >= min(idealListHeight, 200) || availableAbove >= availableBelow
        let maxHeight = max(60, showAbove ? availableAbove : availableBelow)
        let height = inPopover.desiredHeight(maxHeight: min(maxHeight,
                                                            self.mapView.bounds.height * 0.5
                                                           )
        )

        // Center horizontally on marker, clamp to safe bounds
        var x = markerFrame.midX - (width * 0.5)
        x = max(padding + safe.left, min(x,
                                         self.mapView.bounds.width - safe.right - padding - width
                                        )
        )

        let y: CGFloat
        if showAbove {
            y = markerFrame.minY - padding - height
        } else {
            y = markerFrame.maxY + padding
        }

        inPopover.frame = CGRect(x: x,
                                 y: y,
                                 width: width,
                                 height: height
        )
    }

    /* ################################################################## */
    /**
     Returns the opposite of the current UI style.
     
     - parameter inStyle: The style we want reversed.
     - returns: The opposite style.
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
     Apply the correct marker image to the given annotation view, optionally forcing the marker to resolve in the opposite trait mode.
     
     - parameter inView: The annotation view we'll be rendering.
     - parameter inReversed: True, if we have selected the marker.
     */
    @MainActor
    private func _applyMarkerAppearance(to inView: MKAnnotationView,
                                        reversed inReversed: Bool
    ) {
        guard let annotation = inView.annotation as? LocationAnnotation else { return }

        let count = annotation.data.count
        let base = (count == 1) ? self.singleMarkerImage : self.multiMarkerImage

        if inReversed {
            let reversedStyle = self._reversedStyle(for: self.traitCollection.userInterfaceStyle)

            // Force the view itself to render in reversed style.
            inView.overrideUserInterfaceStyle = reversedStyle

            // Build traits that include the reversed userInterfaceStyle, so the image asset resolves correctly.
            let reversedTraits = self.traitCollection.modifyingTraits { $0.userInterfaceStyle = reversedStyle }

            inView.image = self._markerImage(from: base,
                                             compatibleWith: reversedTraits
            )
        } else {
            // Back to normal.
            inView.overrideUserInterfaceStyle = .unspecified
            inView.image = self._markerImage(from: base,
                                             compatibleWith: self.traitCollection
            )
        }

        (inView as? AnnotationView)?.setNeedsLayout()
    }
    
    /* ################################################################## */
    /**
     This returns a marker image that will change when the markers are recalculated.
     
     - parameter inBase: The image that we resize (the original asset).
     - parameter inTraits: The traits style (light or dark) that we want.
     - returns: A scaled, appropriate marker image.
     */
    private func _markerImage(from inBase: UIImage?,
                              compatibleWith inTraits: UITraitCollection
    ) -> UIImage {
        let base = inBase ?? _BJJMAssets._genericMarkerBase
        let resolved = base.imageAsset?.image(with: inTraits) ?? base
        return resolved._scaledToWidth(_BJJMAssets._sMarkerWidthInDisplayUnits)
    }

    /* ################################################################## */
    /**
     This forces the annotations to be recalculated, and set to the map.
     */
    private func _recalculateAnnotations() {
        // Negative inset expands the rect (buffer in map points).
        let buffer: Double = 2_000 // tune for your app
        let visibleRect = self.mapView.visibleMapRect.insetBy(dx: -buffer,
                                                              dy: -buffer
        )

        let visibleAnnotations = self._myAnnotations.filter {
            visibleRect.contains(MKMapPoint($0.coordinate))
        }

        self.mapView.removeAnnotations(self.mapView.annotations)
        self.mapView.addAnnotations(visibleAnnotations)
    }
    
    /* ################################################################## */
    /**
     This creates clusters (multi) annotations, where markers would be close together.
     The Apple clustering algorithm kinda sucks, so we'll do it, ourselves.
     
     - parameter inAnnotations: The annotations to clump.
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
         This generates a CellKey for the given position.
         
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
            let point = self.mapView.convert(inAnnotation.coordinate,
                                             toPointTo: self.mapView
            )
            let baseKey = _cellKey(for: point)
            
            // Try to find an existing cluster in this cell, or adjacent cells, that are within one marker-width on screen.
            var matchKey: _CellKey? = nil
            
            // Yeah, that looks like a GOTO... (Makes sure that break takes us all the way out).
            outer: for deltaX in -1...1 {
                for deltaY in -1...1 {
                    let key = _CellKey(x: baseKey.x + deltaX,
                                       y: baseKey.y + deltaY
                    )
                    if let center = centers[key] {
                        let delta = hypot(center.x - point.x,
                                          center.y - point.y
                        )
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
                existing._mergeIn(inAnnotation)
                
                // Update stored screen center (simple running average by item-count).
                let oldCenter = centers[useKey] ?? point
                let oldCount = max(1,
                                   existing.data.count - inAnnotation.data.count
                )
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

        self.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in self._recalculateAnnotations() }
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
    public func mapView(_ inMapView: MKMapView,
                        viewFor inAnnotation: any MKAnnotation
    ) -> MKAnnotationView? {
        guard let annotation = inAnnotation as? LocationAnnotation else { return nil }
        return AnnotationView(annotation: annotation,
                              controller: self
        )
    }
    
    /* ################################################################## */
    /**
     Called when the map has finished rendering all its tiles. We use it to force the annotations to be recalculated.
     
     - parameter inMapView: The map view being rendered (ignored).
     - parameter fullyRendered: Ignored.
     */
    @MainActor
    public func mapViewDidFinishRenderingMap(_ inMapView: MKMapView,
                                             fullyRendered: Bool
    ) { self._recalculateAnnotations() }
    
    /* ################################################################## */
    /**
     Called when the map has changed its region. We use it to force the annotations to be recalculated.
     
     - parameter inMapView: The map view being rendered (ignored).
     - parameter regionDidChangeAnimated: Ignored.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView,
                        regionDidChangeAnimated: Bool
    ) {
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
     Called when the map is going to change its region.
     
     - parameter inMapView: The map view being rendered (ignored).
     - parameter regionWillChangeAnimated: Ignored.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView,
                        regionWillChangeAnimated: Bool
    ) { self._dismissPopover() }
    
    /* ################################################################## */
    /**
     This is called when a marker is selected.
     
     - parameter inMapView: The map view
     - parameter inView: The marker we're selecting.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView,
                        didSelect inView: MKAnnotationView
    ) {
        if let annotation = inView.annotation as? LocationAnnotation,
           let ignore = self._ignoreNextSelectAnnotation,
           annotation === ignore {
            self._ignoreNextSelectAnnotation = nil
            inMapView.deselectAnnotation(annotation,
                                         animated: false
            )
            return
        }

        guard nil == self._activeAnnotation,
              let annotation = inView.annotation as? LocationAnnotation
        else { return }
        
        self._applyMarkerAppearance(to: inView,
                                    reversed: true
        )
        
        self._dismissPopover()
        self._installDismissTapIfNeeded()
        
        self._activeAnnotation = annotation
        self._activeAnnotationView = inView
        
        let popover = _BJJMMarkerPopoverView()
        self._activePopover = popover
        
        popover.configure(items: annotation.data) { [weak self] item in
            guard let self else { return }
            if !self.stickyPopups {
                inMapView.deselectAnnotation(annotation, animated: true)
            }
            item.callHandler()
        }
        
        self._positionPopover(popover, for: inView)
        popover.setNeedsLayout()
        inMapView.addSubview(popover)
        
        DispatchQueue.main.async { [weak popover] in popover?.layoutIfNeeded() }
    }
    
    /* ################################################################## */
    /**
     This is called when a marker is deselected.
     
     - parameter inMapView: The map view
     - parameter inView: The marker we're deselecting.
     */
    @MainActor
    public func mapView(_ inMapView: MKMapView,
                        didDeselect inView: MKAnnotationView
    ) {
        if inView === self._activeAnnotationView {
            self._dismissPopover()
        }
        
        self._applyMarkerAppearance(to: inView,
                                    reversed: false
        )
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
    public func gestureRecognizer(_ inGestureRecognizer: UIGestureRecognizer,
                                  shouldReceive inTouch: UITouch
    ) -> Bool {
        // Don’t dismiss if the tap is inside the popover.
        if let popover = self._activePopover,
           inTouch.view?.isDescendant(of: popover) == true {
            return false
        }

        // If we tapped the currently-selected marker view, dismiss AND swallow the touch
        // so MKMapView doesn’t immediately re-select it.
        if let activeView = self._activeAnnotationView,
           inTouch.view?.isDescendant(of: activeView) == true {
            inGestureRecognizer.cancelsTouchesInView = true
            return true
        }

        // Otherwise, dismiss but allow the map to also handle the tap (so other markers can select).
        inGestureRecognizer.cancelsTouchesInView = false
        return true
    }
}

/* ################################################################################################################################## */
// MARK: Map Location Data Item Template Protocol
/* ################################################################################################################################## */
/**
 This is used to designate a location, with an attached data entity, and a handler callback.
 */
public protocol BigJuJuMapLocationProtocol: AnyObject, Identifiable, Sendable where ID: Hashable & Sendable {
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
    var handler: @Sendable (_ inItem: any BigJuJuMapLocationProtocol) -> Void { get }
    
    /* ################################################################## */
    /**
     If provided (OPTIONAL, with default being nil), the text in the popover will be displayed in this color.
     */
    var textColor: UIColor? { get }
    
    /* ################################################################## */
    /**
     If provided (OPTIONAL, with default being nil), the text in the popover will be displayed in this font.
     */
    var textFont: UIFont? { get }

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
     Default is nil (whatever the system decides -since it's a button, it's going to be the accent color)
     */
    var textColor: UIColor? { nil }
    
    /* ################################################################## */
    /**
     Default is nil (whatever the system decides)
     */
    var textFont: UIFont? { nil }

    /* ################################################################## */
    /**
     This just calls the handler in the main thread, with this instance as its parameter.
     */
    func callHandler() { Task { @MainActor in self.handler(self) } }
}

/* ################################################################################################################################## */
// MARK: Special Collection Extension, for aggregated data.
/* ################################################################################################################################## */
public extension Collection where Element == any BigJuJuMapLocationProtocol {
    /* ################################################################## */
    /**
     This is just a way of saying "Bogus, dude."
     */
    static var invalidContainingRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: .nan,
                                           longitude: .nan
                                          ),
            span: MKCoordinateSpan(latitudeDelta: .nan,
                                   longitudeDelta: .nan
                                  )
        )
    }
    
    /* ################################################################## */
    /**
     This is just another way of saying "Bogus, dude."
     */
    static var invalidContainingMapRect: MKMapRect { .null }
    
    /* ################################################################## */
    /**
     Returns an MKCoordinateRegion that contains all points in the collection (with padding).
     If the collection is empty, returns  ``invalidContainingRegion``.
     */
    var containingCoordinateRegion: MKCoordinateRegion {
        let coords: [CLLocationCoordinate2D] = self.compactMap {
            let coord = $0.location.coordinate
            return CLLocationCoordinate2DIsValid(coord) ? coord : nil
        }

        guard !coords.isEmpty else { return Self.invalidContainingRegion }

        // Latitude is linear (no wrap)
        var minLat =  90.0
        var maxLat = -90.0

        // Longitude is circular; keep in [-180, 180)
        var lons: [Double] = []
        
        lons.reserveCapacity(coords.count)

        for coord in coords {
            minLat = Swift.min(minLat,
                               coord.latitude
            )
            
            maxLat = Swift.max(maxLat,
                               coord.latitude
            )

            var lon = coord.longitude
            // Normalize to [-180, 180)
            lon = (lon + 180.0).truncatingRemainder(dividingBy: 360.0)
            if lon < 0 { lon += 360.0 }
            lon -= 180.0

            lons.append(lon)
        }

        // Find the smallest arc that contains all longitudes.
        // Classic "minimum window on a circle" by duplicating +360.
        let num = lons.count
        let sorted = lons.sorted()
        var extended = sorted
        extended.reserveCapacity(2 * num)
        extended.append(contentsOf: sorted.map { $0 + 360.0 })

        var bestStartIndex = 0
        var bestSpan = Double.greatestFiniteMagnitude

        if num == 1 {
            bestSpan = 0
            bestStartIndex = 0
        } else {
            for i in 0..<num {
                let start = extended[i]
                let end = extended[i + num - 1]
                let span = end - start
                if span < bestSpan {
                    bestSpan = span
                    bestStartIndex = i
                }
            }
        }

        let lonStart = extended[bestStartIndex]
        let lonCenterRaw = lonStart + (bestSpan * 0.5)

        // Wrap center back to [-180, 180)
        var lonCenter = (lonCenterRaw + 180.0).truncatingRemainder(dividingBy: 360.0)
        if lonCenter < 0 { lonCenter += 360.0 }
        lonCenter -= 180.0

        let latCenter = (minLat + maxLat) * 0.5

        // Padding + minimum deltas
        let latDelta = Swift.max(0.002,
                                 (maxLat - minLat) * 1.20
        )
        let lonSpan = bestSpan // already the *minimal* span (could be 0)
        let lonDelta = Swift.max(0.002,
                                 lonSpan * 1.20
        )

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latCenter,
                                           longitude: lonCenter
                                          ),
            span: MKCoordinateSpan(latitudeDelta: latDelta,
                                   longitudeDelta: lonDelta
                                  )
        )
    }

    /* ################################################################## */
    /**
     Returns an MKMapRect that contains all points, choosing the shortest wrap across the dateline.
     If the collection is empty, returns  ``invalidContainingMapRect``.
     */
    var containingMapRectDatelineAware: MKMapRect {
        let coords: [CLLocationCoordinate2D] = self.compactMap {
            let c = $0.location.coordinate
            return CLLocationCoordinate2DIsValid(c) ? c : nil
        }

        guard !coords.isEmpty else { return Self.invalidContainingMapRect }

        let worldW = MKMapSize.world.width

        // Convert to MKMapPoints
        let points = coords.map { MKMapPoint($0) }

        // Y is linear (no wrap)
        var minY = Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude

        // X wraps (0 ... worldW)
        var xs: [Double] = []
        xs.reserveCapacity(points.count)

        for point in points {
            minY = Swift.min(minY,
                             point.y
            )
            
            maxY = Swift.max(maxY,
                             point.y
            )

            // MKMapPoint.x is already in [0, worldW) for valid coordinates
            xs.append(point.x)
        }

        // Find smallest window on a circle in X-space (like longitude, but in map points)
        let num = xs.count
        let sorted = xs.sorted()
        var extended = sorted
        extended.reserveCapacity(2 * num)
        extended.append(contentsOf: sorted.map { $0 + worldW })

        var bestStartIndex = 0
        var bestSpan = Double.greatestFiniteMagnitude

        if num == 1 {
            bestSpan = 0
            bestStartIndex = 0
        } else {
            for i in 0..<num {
                let start = extended[i]
                let end = extended[i + num - 1]
                let span = end - start
                if span < bestSpan {
                    bestSpan = span
                    bestStartIndex = i
                }
            }
        }

        var minX = extended[bestStartIndex]
        let height = maxY - minY

        // Normalize origin back into [0, worldW)
        // (Rect may still extend beyond worldW; MapKit can handle that for wrapping.)
        if minX >= worldW { minX -= worldW }
        if minX < 0 { minX += worldW }

        var rect = MKMapRect(x: minX,
                             y: minY,
                             width: bestSpan,
                             height: height
        )

        // Add padding (10% each side, with a minimum)
        let padX = Swift.max(rect.size.width * 0.10,
                             5_000
        )
        let padY = Swift.max(rect.size.height * 0.10,
                             5_000
        )
        rect = rect.insetBy(dx: -padX,
                            dy: -padY
        )

        // Ensure not degenerate
        let minSize: Double = 10_000
        if rect.size.width < minSize || rect.size.height < minSize {
            let cx = rect.midX
            let cy = rect.midY
            rect = MKMapRect(x: cx - minSize * 0.5,
                             y: cy - minSize * 0.5,
                             width: minSize,
                             height: minSize
            )
        }

        return rect
    }
    
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

        return CLLocationCoordinate2D(latitude: latSum / count,
                                      longitude: lonSum / count
        )
    }
}
