//
//  ViewController.swift
//  SPCamera App
//
//  Created by Steven G Pint on 12/12/17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit
import SPCamera
import Photos

class ViewController: UIViewController {

//    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    var viewHeightConstraint: NSLayoutConstraint!
    var viewWidthConstraint: NSLayoutConstraint!
//    @IBOutlet var containerHeightConstraint: NSLayoutConstraint!

    let inlineDemo = false
    let containerPortraitHeight: CGFloat = 250
    let containerLandscapeHeight: CGFloat = 200

    lazy var accessoryView: SPAccessoryView = { [unowned self] in
        let view = SPAccessoryView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: ACCESSORY_HEIGHT))
//        noteView.backgroundColor = self.navigationController?.navigationBar.backgroundColor
//        noteView.backgroundColor = UIColor.yellow
//        noteView.delegateAccessory = self

        return view
    }()
    let ACCESSORY_HEIGHT: CGFloat = 50
    var isKeyboardShowing = false

    var cameraViewController: CameraViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.keyboardDismissMode = .interactive
        scrollView.contentSize = self.view.bounds.size
//
//        containerView.backgroundColor = UIColor.lightGray

        #if NO
        if inlineDemo {
            var config = Configuration()
            config.photoAlbumName = "SPCamera"
            config.inlineMode = true

            cameraViewController = CameraViewController(configuration: config,
                onCancel: {},
                onCapture: { (asset) in
                    print("Captured asset")
                    self.metaData(asset)
                }, onFinish: { (assets) in
            })

            if let ctr = cameraViewController {
                addChildViewController(ctr)
                containerView.addSubview(ctr.view)
                ctr.view.translatesAutoresizingMaskIntoConstraints = false

                viewHeightConstraint = ctr.view.heightAnchor.constraint(equalToConstant: containerPortraitHeight)
                viewWidthConstraint = ctr.view.widthAnchor.constraint(equalToConstant: containerLandscapeHeight)
                NSLayoutConstraint.activate([
                    ctr.view.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 0),
                    viewHeightConstraint,
                    viewWidthConstraint,
                    ctr.view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0)
//                    ctr.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0)
                    ])

                ctr.didMove(toParentViewController: self)
            }
        }
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        registerNotifications()

        if accessoryView.accessoryViewHeightConstraint == nil {
            for constraint in accessoryView.constraints {
                if constraint.firstAttribute == .height {
                    accessoryView.accessoryViewHeightConstraint = constraint
                    break
                }
            }
        }
        setAccessoryHeight()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        #if NO
        if inlineDemo {
            let deviceOrientation = UIDevice.current.orientation
            if deviceOrientation.isPortrait {
                containerHeightConstraint.constant = containerPortraitHeight
                viewHeightConstraint.constant = containerPortraitHeight
                viewWidthConstraint.constant = containerLandscapeHeight
            } else {
                containerHeightConstraint.constant = containerLandscapeHeight
                viewHeightConstraint.constant = containerLandscapeHeight
                viewWidthConstraint.constant = containerPortraitHeight
            }

//            print("container bounds: \(NSStringFromCGRect(containerView.bounds))")
//            print("preview bounds: \(NSStringFromCGRect(cameraViewController?.previewRect ?? CGRect.zero))")

//            viewWidthConstraint.constant = containerView.bounds.size.width
    //        cameraViewController?.view.frame = containerView.bounds
        }
        #endif
    }

    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(UIKeyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
    }

    @objc func UIKeyboardWillShow(_ notification: NSNotification) {
        let userInfo = notification.userInfo!
        let beginFrameValue = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)!
        let beginFrame = beginFrameValue.cgRectValue
        let endFrameValue = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)!
        let endFrame = endFrameValue.cgRectValue
        if beginFrame.size.equalTo(endFrame.size) {
            return
        }
        if #available(iOS 11.0, *) {
            let begHeight = beginFrame.size.height - view.safeAreaInsets.bottom
            if begHeight == endFrame.size.height {
                return
            }
            let endHeight = endFrame.size.height - view.safeAreaInsets.bottom
            if endHeight == beginFrame.size.height {
                return
            }
        }

        layoutWithKeyboardFrame(notification, willShow: true)
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        layoutWithKeyboardFrame(notification, willShow: false)
    }

    func layoutWithKeyboardFrame(_ notification: NSNotification, willShow: Bool) {
        if !isViewLoaded {
            return
        }

        isKeyboardShowing = willShow
        if let info = notification.userInfo, let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let animationDuration = info[UIKeyboardAnimationDurationUserInfoKey] as? Double {

            var contentInset = scrollView.contentInset
            contentInset.bottom = keyboardFrame.height

            let diff = view.bounds.height - keyboardFrame.height - (navigationController?.navigationBar.frame.height ?? 0) - 44 //UIApplication.statusBarHeight()
            //            logv("diff: \(diff)")

            UIView.animate(withDuration: animationDuration) {
                self.scrollView.contentInset = contentInset
                self.scrollView.scrollIndicatorInsets = contentInset

                self.setAccessoryHeight()

//                self.accessoryView.accessoryViewHeightConstraint?.constant = 88
//                self.accessoryView.maxHeight = diff
//                print("maxHeight: \(self.accessoryView.maxHeight)")
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

    }

    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        setAccessoryHeight()
    }

    func setAccessoryHeight() {
        print("setAccessoryHeight")
        if #available(iOS 11.0, *) {
            print("safe area insets 3: \(view.safeAreaInsets) isKeyboardShowing: \(isKeyboardShowing)")
            self.accessoryView.accessoryViewHeightConstraint?.constant = ACCESSORY_HEIGHT + (isKeyboardShowing ? 0 : view.safeAreaInsets.bottom)
        } else {
            self.accessoryView.accessoryViewHeightConstraint?.constant = ACCESSORY_HEIGHT
        }
    }

    // MARK: - accessory view

    override var inputAccessoryView: UIView? {
        get {
            return accessoryView
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    @IBAction func launchTouched(_ sender: UIButton) {
        var config = Configuration()
        config.photoAlbumName = "SPCamera"

        let ctr = CameraViewController(configuration: config,
        onCancel: {
            self.dismiss(animated: true, completion: nil)
        }, onCapture: { (asset) in
            print("Captured asset")
            self.metaData(asset)
        }, onFinish: { assets in
            print("Finished")
        })
        present(ctr, animated: true, completion: nil)
    }

    @IBAction func signInTouched(_ sender: Any) {
        AppDelegate.displaySignInScreen(transition: true)
    }

    // calls to capture photo metadata
    func metaData(_ photoAsset: PHAsset) {
        photoAsset.requestMetadata(withCompletionBlock: { (info) in
            // print("photo metadata: \(info)")
            if let info = info, let gpsInfo = info["{GPS}"] as? [String: Any] {
                if let direction = gpsInfo["ImgDirection"] as? Double {
                    print("photo {GPS} direction metadata: \(direction)")
                } else {
                    print("photo {GPS} metadata: \(gpsInfo)")
                }
            }
        })
    }

}

public extension PHAsset {

    public func requestMetadata(withCompletionBlock completionBlock: @escaping (([String: Any]?) -> Void)) {
        DispatchQueue.global(qos: .default).async(execute: {() -> Void in
            let editOptions = PHContentEditingInputRequestOptions()
            editOptions.isNetworkAccessAllowed = true
            self.requestContentEditingInput(with: editOptions, completionHandler: { (contentEditingInput, info) -> Void in
                if let input = contentEditingInput, let url = input.fullSizeImageURL {
                    let image = CIImage(contentsOf: url)
                    DispatchQueue.main.async(execute: {() -> Void in
                        completionBlock(image?.properties)
                    })
                } else {
                    DispatchQueue.main.async(execute: {() -> Void in
                        completionBlock(nil)
                    })
                }
            })
        })
    }
}
