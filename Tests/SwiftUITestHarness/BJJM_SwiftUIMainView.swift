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

/* ################################################################################################################################## */
// MARK: - UIViewControllerRepresentable Wrapper for the Map View Controller -
/* ################################################################################################################################## */
/**
 
 */
struct BJJM_BigJuJuMapViewController: UIViewControllerRepresentable {
    /* ################################################################## */
    /**
     */
    typealias UIViewControllerType = BigJuJuMapViewController
    
    /* ################################################################## */
    /**
     */
    var onDismiss: (() -> Void)?

    /* ################################################################## */
    /**
     */
    func makeUIViewController(context inContext: Context) -> BigJuJuMap.BigJuJuMapViewController {
        BigJuJuMap.BigJuJuMapViewController()
    }
    
    /* ################################################################## */
    /**
     */
    func updateUIViewController(_ inUIViewController: BigJuJuMap.BigJuJuMapViewController, context inContext: Context) {
    }
}

/* ################################################################################################################################## */
// MARK: - UIKit Segmented Control Wrapper (Images) -
/* ################################################################################################################################## */
/**
 
 */
struct BJJM_ImageSegmentedControl: UIViewRepresentable {
    /* ################################################################## */
    /**
     */
    typealias UIViewType = UISegmentedControl

    /* ################################################################## */
    /**
     */
    private static let _iconSize: CGSize = CGSize(width: 30, height: 30)

    /* ################################################################## */
    /**
     */
    let imageNames: [String]

    /* ################################################################## */
    /**
     */
    @Binding var selectedIndex: Int

    /* ################################################################## */
    /**
     */
    var backgroundColor: UIColor = .systemGray4

    /* ################################################################## */
    /**
     */
    var selectedTintColor: UIColor = .systemBlue

    /* ################################################################## */
    /**
     */
    var onChange: (Int) -> Void = { _ in }

    /* ################################################################## */
    /**
     */
    func makeUIView(context inContext: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: Array(repeating: "", count: self.imageNames.count))

        // Match UIKit-ish appearance
        control.backgroundColor = self.backgroundColor
        control.selectedSegmentTintColor = self.selectedTintColor

        // Remove default text styling impact
        control.setTitleTextAttributes([.foregroundColor: UIColor.clear], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.clear], for: .selected)

        control.addTarget(inContext.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)

        for (idx, name) in imageNames.enumerated() {
            if let img = UIImage(named: name) {
                let fitted = img._aspectFit(in: Self._iconSize)
                control.setImage(fitted.withRenderingMode(.alwaysTemplate), forSegmentAt: idx)
            }
        }

        control.selectedSegmentIndex = self.selectedIndex
        return control
    }

    /* ################################################################## */
    /**
     */
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != self.selectedIndex {
            uiView.selectedSegmentIndex = self.selectedIndex
        }

        uiView.backgroundColor = self.backgroundColor
        uiView.selectedSegmentTintColor = self.selectedTintColor
    }

    /* ################################################################## */
    /**
     */
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /* ############################################################################################################################## */
    // MARK: Change Handler
    /* ############################################################################################################################## */
    /**
     
     */
    final class Coordinator: NSObject {
        /* ############################################################## */
        /**
         */
        var parent: BJJM_ImageSegmentedControl

        /* ################################################################## */
        /**
         */
        init(_ inParent: BJJM_ImageSegmentedControl) {
            self.parent = inParent
        }

        /* ################################################################## */
        /**
         */
        @objc func changed(_ inControl: UISegmentedControl) {
            self.parent.selectedIndex = inControl.selectedSegmentIndex
            self.parent.onChange(inControl.selectedSegmentIndex)
        }
    }
}

/* ################################################################################################################################## */
// MARK: UIImage Resizing Extension
/* ################################################################################################################################## */
private extension UIImage {
    /* ################################################################## */
    /**
     UIImage helper: aspect-fit into a target box
     */
    func _aspectFit(in target: CGSize) -> UIImage {
        let scale = min(target.width / self.size.width, target.height / self.size.height)
        let newSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            let origin = CGPoint(
                x: (target.width - newSize.width) * 0.5,
                y: (target.height - newSize.height) * 0.5
            )
            self.draw(in: CGRect(origin: origin, size: newSize))
        }
    }
}

/* ################################################################################################################################## */
// MARK: - Main View Class -
/* ################################################################################################################################## */
/**
 
 */
struct BJJM_SwiftUIMainView: View {
    /* ################################################################## */
    /**
     */
    @State private var _topIndex: Int = 0

    /* ################################################################## */
    /**
     */
    @State private var _bottomIndex: Int = 0

    /* ################################################################## */
    /**
     */
    private let _topImages = [
        "TemplateBuiltIn",     // <- change to your real names
        "TemplateEnum",
        "TemplateCustom"
    ]

    /* ################################################################## */
    /**
     */
    var body: some View {
        ZStack {
            Color.blue.opacity(0.35).ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                BJJM_ImageSegmentedControl(
                    imageNames: self._topImages,
                    selectedIndex: self.$_topIndex,
                    backgroundColor: .systemGray4,
                    selectedTintColor: UIColor(Color.accentColor),
                    onChange: { _ in
                    }
                )
                .frame(height: 44)

                Picker("", selection: self.$_bottomIndex) {
                    Text("USA").tag(0)
                    Text("Omaha").tag(1)
                    Text("Philadelphia").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: self._bottomIndex) { _, _ in
                }
            }
            .padding(.horizontal, 16)
            .background(.thinMaterial)
            .tint(.accentColor)
        }
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.accentColor)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        }
    }
}
