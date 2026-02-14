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

import SwiftUI
import UIKit
import BigJuJuMap
import RVS_Generic_Swift_Toolbox
import TabularData
import CoreLocation

/* ################################################################################################################################## */
// MARK: - UIViewControllerRepresentable Wrapper for the Map View Controller -
/* ################################################################################################################################## */
/**
 This is how we integrate the UIKit BigJuJuMap into the SwiftUI app.
 We wrap it in a UIViewControllerRepresentable struct.
 */
struct BJJM_BigJuJuMapViewController: UIViewControllerRepresentable {
    /* ############################################################################################################################## */
    // MARK: - UIViewControllerRepresentable Wrapper for the Map View Controller -
    /* ############################################################################################################################## */
    /**
     This is used to determine when we need to update the map data and the region.
     */
    final class Coordinator {
        /* ################################################################## */
        /**
         This is a hash that represents the "expensive" state of the map (the map data). The markers are not tracked.
         */
        var lastSignature: UInt64 = 0
    }

    /* ################################################################## */
    /**
     The controller is our wrapped BigJuJuMapViewController type.
     */
    typealias UIViewControllerType = BigJuJuMapViewController

    /* ################################################################## */
    /**
     The image names for our current markers.
     */
    let markerNames: (single: String, multi: String)

    /* ################################################################## */
    /**
     The filename for the dataset we're using.
     */
    let dataSetName: String

    /* ################################################################## */
    /**
     True, if we are displaying numbers over the markers.
     */
    var displayNumbers = true

    /* ################################################################## */
    /**
     The signature of our tapped item callback.
     The parameter is the data item that was selected. It is always called in the main thread.
     */
    var onTap: (@MainActor (_: any BigJuJuMapLocationProtocol) -> Void)? = nil

    /* ################################################################## */
    /**
     This instantiates our context coordinator.
     */
    func makeCoordinator() -> Coordinator { Coordinator() }

    /* ################################################################## */
    /**
     This instantiates our view controller class.
     */
    func makeUIViewController(context: Context) -> BigJuJuMap.BigJuJuMapViewController {
        BigJuJuMap.BigJuJuMapViewController()
    }

    /* ################################################################## */
    /**
     Called when the view updates.
     */
    func updateUIViewController(_ inUIViewController: BigJuJuMap.BigJuJuMapViewController,
                                context inContext: Context
    ) {
        guard let dataFrame = BJJM_LocationFactory.locationData(from: self.dataSetName),
              let onTap
        else { return }

        // Build a signature for “what the map data would be” without needing Equatable.
        // Include dataSetName so switching datasets always triggers.
        var hasher = Hasher()
        hasher.combine(self.dataSetName)
        hasher.combine(dataFrame.rows.count)
        var stickyPopups = false

        // We prepare the location data for the map. We also set the state hasher.
        let locations: [any BigJuJuMapLocationProtocol] = dataFrame.rows.flatMap { inRow -> [any BigJuJuMapLocationProtocol] in
            guard let id = inRow.int("id"),
                  let name = inRow.string("name"),
                  let latitude = inRow.double("latitude"),
                  let longitude = inRow.double("longitude")
            else { return [] }

            // Fold the data into the hash (Round the position to avoid float noise).
            hasher.combine(id)
            hasher.combine(name)
            hasher.combine(Int((latitude  * 1_000_000).rounded()))
            hasher.combine(Int((longitude * 1_000_000).rounded()))
            
            var textColor: UIColor?
            var textFont: UIFont?
            
            switch self.dataSetName {
            case "SLUG-USA".localizedVariant:
                textColor = .red
                textFont = UIFont.preferredFont(forTextStyle: .caption1)
                stickyPopups = true
                
            case "SLUG-VI".localizedVariant:
                textColor = .green
                textFont = UIFont.preferredFont(forTextStyle: .largeTitle)

            default:
                break
            }

            return [BJJM_MapLocation(id: id,
                                     name: name,
                                     latitude: latitude,
                                     longitude: longitude,
                                     textColor: textColor,
                                     textFont: textFont
                                    ) { inItem in Task { @MainActor in onTap(inItem) } }]
        }

        // Convert Hasher's Int to a stable-ish UInt64 for storage.
        // (Within a single run, this is fine for "did it change since last update?")
        let signature = UInt64(bitPattern: Int64(hasher.finalize()))

        // Update marker config every time (cheap + independent of data).
        let singleName: String = self.markerNames.single.isEmpty ? "" : self.markerNames.single
        let multiName: String = self.markerNames.multi.isEmpty ? "" : self.markerNames.multi

        let singleImage: UIImage? = singleName.isEmpty ? nil : UIImage(named: singleName)
        let multiImage: UIImage? = multiName.isEmpty ? nil : UIImage(named: multiName)

        inUIViewController.singleMarkerImage = singleImage
        inUIViewController.multiMarkerImage = multiImage
        inUIViewController.displayNumbers = (singleName == multiName) ? true : self.displayNumbers
        inUIViewController.stickyPopups = stickyPopups

        // Gate the expensive operations. We don't want to zoom away/out the map, unless we are changing the data, itself.
        guard inContext.coordinator.lastSignature != signature else { return }
        inContext.coordinator.lastSignature = signature
        inUIViewController.mapData = locations
        inUIViewController.visibleRect = locations.containingMapRectDatelineAware
    }
}

/* ################################################################################################################################## */
// MARK: - Main View Class -
/* ################################################################################################################################## */
/**
 This displays a view, with the map filling the screen, behind  two segmented switches for selecting the marker and the dataset.
 */
struct BJJM_SwiftUIMainView: View {
    /* ################################################################## */
    /**
     These are the strings we use for the top segmented switch.
     */
    private static let _topStrings = ["SLUG-DM".localizedVariant, "SLUG-C1".localizedVariant, "SLUG-C2".localizedVariant]
    
    /* ################################################################## */
    /**
     These are the strings we use for the bottom segmented switch.
     */
    private static let _bottomOptions = ["SLUG-NC".localizedVariant, "SLUG-USA".localizedVariant, "SLUG-VI".localizedVariant]
    
    /* ################################################################## */
    /**
     These are the names of the marker images.
     */
    private static let _topOptions: [(single: String, multi: String)] = [
        (single: "", multi: ""),
        (single: "CustomGeneric", multi: "CustomGeneric"),
        (single: "CustomSingle", multi: "CustomMulti")
    ]
    
    /* ################################################################## */
    /**
     The currently selected top segment.
     */
    @State private var _topIndex: Int = 0
    
    /* ################################################################## */
    /**
     The currently selected bottom segment.
     */
    @State private var _bottomIndex: Int = 0
    
    /* ################################################################## */
    /**
     This is true, when we want to display an alert, upon selecting a popover item.
     */
    @State private var _showingAlert: Bool = false
    
    /* ################################################################## */
    /**
     This is the text we want displayed in the alert.
     */
    @State private var _alertMessage: String = ""

    /* ################################################################## */
    /**
     This returns a view, with the map filling the screen, behind the two segmented switches.
     */
    var body: some View {
        BJJM_BigJuJuMapViewController(markerNames: Self._topOptions[self._topIndex],
                                      dataSetName: Self._bottomOptions[self._bottomIndex]
        ) { inItem in
            self._alertMessage = String(format: "SLUG-ALERT-FORMAT".localizedVariant,
                                        inItem.name
            )
            self._showingAlert = true
        }
            .ignoresSafeArea(.all)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Picker("",
                           selection: self.$_topIndex
                    ) {
                        ForEach(Self._topStrings.indices,
                                id: \.self
                        ) { index in
                            Text(Self._topStrings[index])
                                .tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("", selection: self.$_bottomIndex) {
                        ForEach(Self._bottomOptions.indices,
                                id: \.self
                        ) { index in
                            Text(Self._bottomOptions[index])
                                .tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top,
                             6
                    )
                }
                .padding(.horizontal,
                         16
                )
                .background(.clear)
                .tint(.accentColor)
            }
            .alert("SLUG-ALERT-HEADER".localizedVariant,
                   isPresented: self.$_showingAlert
            ) {
                Button("SLUG-OK".localizedVariant,
                       role: .cancel
                ) { }
            } message: {
                Text(self._alertMessage)
            }
            .onAppear {
                // Set up the appearance of the two segmented switches.
                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.accentColor)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white],
                                                                       for: .selected
                )
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.label],
                                                                       for: .normal
                )
            }
    }
}
