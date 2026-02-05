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

/* ################################################################################################################################## */
// MARK: Main App Delegate Class
/* ################################################################################################################################## */
/**
 The main app delegate.
 */
@main
class BJJM_AppDelegate: UIResponder, UIApplicationDelegate {
    /* ################################################################## */
    /**
     Called when the app has loaded
     
     - parameter inApplication: The application instance (ignored).
     - parameter didFinishLaunchingWithOptions: The launch options (also ignored).
     - returns: True, always.
     */
    func application(_ inApplication: UIApplication, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }

    // MARK: UISceneSession Lifecycle

    /* ################################################################## */
    /**
     Called to connect the scene to the app.
     
     - parameter inApplication: The application instance (ignored).
     - parameter inConnectingSession: The session we are connecting.
     - parameter options: The connection options (also ignored).
     - returns: A scene configuration for the scene being connected.
     */
    func application(_ inApplication: UIApplication, configurationForConnecting inConnectingSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: inConnectingSession.role)
    }
}
