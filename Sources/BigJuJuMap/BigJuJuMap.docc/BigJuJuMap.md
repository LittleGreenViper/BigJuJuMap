# ``BigJuJuMap``

![](icon.png)

A Self-Contained Map With Multiple, Aggregated, Custom Markers

## Overview

This package was specifically designed to offer [`SwiftUI`](https://developer.apple.com/swiftui/) apps the opportunity to have a much more involved map experience than that provided by default.

It also allows a "drop in" high-functionality map for [`UIKit`](https://developer.apple.com/documentation/uikit/) projects.

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

### Examples (The Test Harness Apps)

There are two test harness targets provided with the library: A UIKit target, and a SwiftUI target. They show simple implementations of BigJuJuMap, in practice.

They are visually identical, presenting a single screen, filled with a map, and displaying a number of markers. At the bottom of the screen, are two segmented switches. The top switch selects which type of marker to display (default, custom simple, or custom complex).

#### Markers

The following images show the types of markers that can be selected by the app.

The marker selection is made by changing the top segmented switch. Changing the marker does not affect the displayed region.

##### Figure 1: Default Markers

| ![](Fig-01-DefaultMarkers-Light.png) | ![](Fig-01-DefaultMarkers-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

##### Figure 2: Custom Markers With Space for Numbers

| ![](Fig-02-CustomMarkers-1-Light.png) | ![](Fig-02-CustomMarkers-1-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

##### Figure 3: Custom Markers With No Numbers

| ![](Fig-03-CustomMarkers-2-Light.png) | ![](Fig-03-CustomMarkers-2-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

#### Datasets

The following images show the test datasets we use.

The dataset selection is made by selecting one of the values in the bottom segmented switch. The map is changed to display the new dataset.

##### Figure 4: State Parks in North Carolina

| ![](Fig-04-NC-Light.png) | ![](Fig-04-NC-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

> NOTE: Because the total area for this dataset is so large, Apple Maps limits the size of the region. If you scroll West, a bit, you'll see American Samoa.

##### Figure 5: National Parks

| ![](Fig-05-USA-Light.png) | ![](Fig-05-USA-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

##### Figure 6: Territorial Parks in the US Virgin Islands

| ![](Fig-06-VI-Light.png) | ![](Fig-06-VI-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

#### Popovers

When we select a marker, a popover appears, above or below the marker.

In the case of aggregate markers, a scrolling table of values is shown.

##### Figure 7: Example of A Large Aggregate Marker

| ![](Fig-07-LargePopover-Light.png) | ![](Fig-07-LargePopover-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

For a single marker, only one value is shown.

##### Figure 8: Example of A Single Marker

| ![](Fig-08-Small-Popover-Light.png) | ![](Fig-08-Small-Popover-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

#### Reaction Alerts

When we select one of the values in a popover, the popover is dismissed, and this alert is shown:

##### Figure 9: Alert Displayed When Selecting A Row in A Popover

| ![](Fig-09-Alert-Light.png) | ![](Fig-09-Alert-Dark.png) |
|:-:|:-:|
| *Light Mode* | *Dark Mode* |

### The API

#### The View Controller

Once we have included the package into our source file, then we can simply use the Storyboard Editor to create the instance:

![](Fig-10-Storyboard-Editor.png)

Or just instantiate it directly:

    self.bigJuJuMap = BigJuJuMapViewController()
    self.navigationController?.pushViewController(self.bigJuJuMap, animated: true)

#### The Map Data

Once we have the view controller ready to go, we need to give it its dataset, which is simply an array of data items that conform to ``BigJuJuMapLocationProtocol``. The test harnesses demonstrate this with simple datasets of US national and state parks.

This is demonstrated in the [`BJJM_LocationFactory`](https://github.com/LittleGreenViper/BigJuJuMap/blob/master/Tests/Shared/Sources/BJJM_LocationFactory.swift#L31) struct, shared between the UIKit and SwiftUI test harness apps.

Simply set the ``BigJuJuMapViewController/mapData`` property to the array, and you're good to go. You may also want to set the map's region. The BigJuJuMap package exports some helpers, to make it easy to calculate from the data array.

You can directly access the [`MKMapView`](https://developer.apple.com/documentation/mapkit/mkmapview) instance, by referencing the ``BigJuJuMapViewController/mapView`` computed property. The view controller's main [`view`](https://developer.apple.com/documentation/uikit/uiviewcontroller/view) property is also the mapView, but referenced as a top-level [UIView](https://developer.apple.com/documentation/UIKit/UIView), not [`MKMapView`](https://developer.apple.com/documentation/mapkit/mkmapview).

#### The Markers

You provide your own custom markers, by giving the ``BigJuJuMapViewController`` instance [`UIImage`](https://developer.apple.com/documentation/uikit/uiimage/)s. These will be resized, in the map, but they should have a roughly 1:2 aspect ratio. If you will choose to have ``BigJuJuMapViewController/displayNumbers`` as true (the default), then the marker images should have a large blank area in the upper portion, that will not obscure labels displayed with the [`UIColor.label`](https://developer.apple.com/documentation/uikit/uicolor/label) color.

You provide the images by setting the ``BigJuJuMapViewController/singleMarkerImage`` and ``BigJuJuMapViewController/multiMarkerImage`` properties. Leaving them as nil, will cause the built-in (upside-down teardrop) marker to be used.

> NOTE: If you want the same image to be used for both ("Custom 1," in the test harness apps), then you need to provide the same image to **BOTH** of the properties.

#### Additional Settings

You can specify a font and color to be used, in data items. If these are present, the text in the popover for that item will be displayed with the color and font provided. Otherwise, the standard button font and color will be used.

You can set `BigJuJuMapViewController/displayNumbers`` to false, and the numbers for aggregate markers will not display (for example, if you have intricate custom markers, the numbers will interfere).

You can set ``BigJuJuMapViewController/stickyPopups`` to true, and the popovers will not dismiss, when an item is selected.

## Usage in SwiftUI

SwiftUI has a very limited support for MapKit, which was why this package was written. In order to use it in SwiftUI, you need to wrap it in a [`UIViewControllerRepresentable`](https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable/) instance. This is demonstrated in the SwiftUI test harness, in the 
[`BJJM_BigJuJuMapViewController`](https://github.com/LittleGreenViper/BigJuJuMap/blob/master/Tests/SwiftUITestHarness/BJJM_SwiftUIMainView.swift#L27) struct.
