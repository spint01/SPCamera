//
//  ViewController.swift
//  Example
//
//  Created by Steven G Pint on 12/12/17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit
import SPCamera
import Photos

class ViewController: UIViewController {

    @IBOutlet weak var containerView: UIView!

    let inlineDemo = true

    override func viewDidLoad() {
        super.viewDidLoad()

        containerView.backgroundColor = UIColor.lightGray

        if inlineDemo {
            var config = Configuration()
            config.photoAlbumName = "SPCamera"
            config.inlineMode = true

            let ctr = CameraViewController(configuration: config,
                onCancel: {},
                onCapture: { (asset) in
                    print("Captured asset")
                    self.metaData(asset)
                }, onFinish: { (assets) in
            })

            addChildViewController(ctr)
            containerView.addSubview(ctr.view)
            ctr.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                ctr.view.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 0),
                ctr.view.widthAnchor.constraint(equalToConstant: 150),
                ctr.view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0),
                ctr.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0)
                ])

            ctr.didMove(toParentViewController: self)
        }
    }

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

