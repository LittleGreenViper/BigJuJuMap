# ``BigJuJuMap``

A Self-Contained Map With Multiple, Aggregated, Custom Markers

## Overview

This package was specifically designed to offer SwiftUI apps the opportunity to have a much more involved map experience than that provided by default.

It also allows a "drop in" high-functionality map for UIKit projects.

## How Does It Work?

The implementation is provided as a static [framework](https://developer.apple.com/documentation/xcode/creating-a-static-framework), instantiating a custom [UIViewController](https://developer.apple.com/documentation/UIKit/UIViewController) subclass (``BigJuJuMapViewController``).

## Usage

The library is designed to be installed as a [Swift Package Manager (SPM)](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/) package. The package is available from [GitHub](https://github.com/LittleGreenViper/BigJuJuMap). A direct SPM URI is `git@github.com:LittleGreenViper/BigJuJuMap.git`.

Add the package to your project, and include it into your target.

Whenever you use it, you will need to import it, thusly:

    import BigJuJuMap
    
You use it by instantiating ``BigJuJuMapViewController``, and providing it with a dataset (the dataset must conform to the ``BigJuJuMapLocationProtocol`` protocol, and must be a class; not a struct).

You can also, optionally, provide the view controller with alternate marker graphic assets (the default is a simple map marker).

Additionally, you can choose to have the number of aggregated data points displayed in aggregate (multi) markers.

### Examples

There are two test harness targets provided with the library: A UIKit target, and a SwiftUI target. They show simple implementations of BigJuJuMap, in practice.

They are visually identical, presenting a single screen, filled with a map, and displaying a number of markers. At the bottom of the screen, are two segmented switches. The top switch selects which type of marker to display (default, custom simple, or custom complex).
