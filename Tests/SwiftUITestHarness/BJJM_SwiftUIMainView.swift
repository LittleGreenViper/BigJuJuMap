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

// MARK: - UIKit Segmented Control Wrapper (Images)
struct BJJM_ImageSegmentedControl: UIViewRepresentable {
    typealias UIViewType = UISegmentedControl

    let imageNames: [String]          // Asset names in your xcassets
    @Binding var selectedIndex: Int

    var iconSize: CGSize = CGSize(width: 90, height: 32)   // "label" box for each segment’s image
    var backgroundColor: UIColor = .systemGray4
    var selectedTintColor: UIColor = .systemBlue

    // Empty handler closure (wire later)
    var onChange: (Int) -> Void = { _ in }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: Array(repeating: "", count: imageNames.count))

        // Match UIKit-ish appearance
        control.backgroundColor = backgroundColor
        control.selectedSegmentTintColor = selectedTintColor

        // Remove default text styling impact
        control.setTitleTextAttributes([.foregroundColor: UIColor.clear], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.clear], for: .selected)

        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)

        // Set images (aspect-fit into a fixed box)
        for (idx, name) in imageNames.enumerated() {
            if let img = UIImage(named: name) {
                let fitted = img.bjjm_aspectFit(in: iconSize)
                // Preserve your artwork colors (don’t template-tint it)
                control.setImage(fitted.withRenderingMode(.alwaysOriginal), forSegmentAt: idx)
            }
        }

        control.selectedSegmentIndex = selectedIndex
        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        // Keep selection in sync
        if uiView.selectedSegmentIndex != selectedIndex {
            uiView.selectedSegmentIndex = selectedIndex
        }

        // In case you change traits / colors dynamically:
        uiView.backgroundColor = backgroundColor
        uiView.selectedSegmentTintColor = selectedTintColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: BJJM_ImageSegmentedControl
        init(_ parent: BJJM_ImageSegmentedControl) { self.parent = parent }

        @objc func changed(_ sender: UISegmentedControl) {
            parent.selectedIndex = sender.selectedSegmentIndex
            parent.onChange(sender.selectedSegmentIndex)   // empty by default
        }
    }
}

// MARK: - UIImage helper: aspect-fit into a target box
private extension UIImage {
    func bjjm_aspectFit(in target: CGSize) -> UIImage {
        let scale = min(target.width / size.width, target.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            let origin = CGPoint(
                x: (target.width - newSize.width) * 0.5,
                y: (target.height - newSize.height) * 0.5
            )
            draw(in: CGRect(origin: origin, size: newSize))
        }
    }
}

/* ################################################################################################################################## */
// MARK: Main View Class
/* ################################################################################################################################## */
/**
 
 */
struct BJJM_SwiftUIMainView: View {
    @State private var topIndex: Int = 0
    @State private var bottomIndex: Int = 0

    // Use your *actual* asset names from the UIKit project:
    private let topImages = [
        "TemplateBuiltIn",     // <- change to your real names
        "TemplateEnum",
        "TemplateCustom"
    ]

    var body: some View {
        ZStack {
            Color.blue.opacity(0.35).ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {

                // TOP: UIKit-accurate segmented control with images
                BJJM_ImageSegmentedControl(
                    imageNames: topImages,
                    selectedIndex: $topIndex,
                    iconSize: CGSize(width: 90, height: 30),
                    backgroundColor: .systemGray4,
                    selectedTintColor: .systemBlue,
                    onChange: { _ in }    // empty handler
                )
                .frame(height: 44)

                // BOTTOM: you can keep SwiftUI Picker (or wrap another UISegmentedControl)
                Picker("", selection: $bottomIndex) {
                    Text("USA").tag(0)
                    Text("Omaha").tag(1)
                    Text("Philadelphia").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: bottomIndex) { _, _ in
                    // empty handler
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.thinMaterial)
        }
    }
}
