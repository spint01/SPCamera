//
//  AppDelegate.swift
//  SPCamera App
//
//  Created by Steven G Pint on 12/12/17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit

// keep a reference so we can return to it when logging out
var mainViewController: UIViewController?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        self.window = UIWindow(frame: UIScreen.main.bounds)
        AppDelegate.displayMainScreen(self.window)

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    class func displayMainScreen(_ window: UIWindow? = UIApplication.shared.keyWindow) {
        // NOTE: We start the timer here since we have successfully logged in
        if let w = window {
//            if mainViewController == nil {
                let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
                mainViewController = storyboard.instantiateViewController(withIdentifier: "NavMenuViewController")
//            }
            if let ctr = mainViewController {
                w.rootViewController = ctr
                w.makeKeyAndVisible()
            }
        }
    }

    class func displaySignInScreen(_ window: UIWindow? = UIApplication.shared.keyWindow, transition: Bool = false) {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let navCtr = storyboard.instantiateViewController(withIdentifier: "SignInViewController")
        if let w = window {
            w.rootViewController = navCtr
            w.makeKeyAndVisible()
        }
    }
}


@objc
public extension UIView {

    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable var borderColor: UIColor? {
        get {
            return UIColor(cgColor: layer.borderColor!)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }
}
