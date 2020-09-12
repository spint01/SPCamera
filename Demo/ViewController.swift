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

    @IBOutlet weak var containerView: UIView!

    var viewHeightConstraint: NSLayoutConstraint!
    var viewWidthConstraint: NSLayoutConstraint!
    @IBOutlet var containerHeightConstraint: NSLayoutConstraint!

    let inlineDemo = false
    let containerPortraitHeight: CGFloat = 250
    let containerLandscapeHeight: CGFloat = 200

    var cameraViewController: CameraViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        containerView.backgroundColor = UIColor.lightGray

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
                    print(assets)
                }, onPreview: { (assets) in
                    print("Preview")
            })

            if let ctr = cameraViewController {
                addChild(ctr)
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

                ctr.didMove(toParent: self)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

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
    }

//    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        super.viewWillTransition(to: size, with: coordinator)
//
//        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
//            let deviceOrientation = UIDevice.current.orientation
//            guard let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
//                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
//                    return
//            }
//
//            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
//        }
//    }

    @IBAction func singlePhotoTouched(_ sender: UIButton) {
        launchSPCamera(false)
    }

    @IBAction func multiplePhotoTouched(_ sender: UIButton) {
        launchSPCamera(true)
    }

    func launchSPCamera(_ allowMultiplePhotoCapture: Bool) {
        var config = Configuration()
        config.photoAlbumName = "SPCamera"
        config.allowMultiplePhotoCapture = allowMultiplePhotoCapture
        config.doneButtonTitle = "Done"
        config.cancelButtonTitle = "Cancel"

        let ctr = CameraViewController(configuration: config,
            onCancel: {
                self.dismiss(animated: true, completion: nil)
            }, onCapture: { (asset) in
                print("Captured asset")
                self.metaData(asset)
                if !allowMultiplePhotoCapture {
                    self.dismiss(animated: true, completion: nil)
                }
            }, onFinish: { assets in
                print("Finished")
                self.dismiss(animated: true, completion: nil)
            }, onPreview: { (assets) in
                print("Preview")
                print(assets)
            }
        )
        ctr.modalPresentationStyle = .fullScreen
        present(ctr, animated: true, completion: nil)
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

    func requestMetadata(withCompletionBlock completionBlock: @escaping (([String: Any]?) -> Void)) {
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

