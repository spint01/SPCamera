//
//  ViewController.swift
//  Example
//
//  Created by Steven G Pint on 12/12/17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit
import SPCamera

class ViewController: UIViewController {

    @IBOutlet weak var containerView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()

        containerView.backgroundColor = UIColor.lightGray

        var config = Configuration()
        config.photoAlbumName = "SPCamera"
        config.inlineMode = true

        let ctr = CameraViewController(configuration: config,
            onCancel: {},
            onCapture: { (asset) in
                print("Captured asset")
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

    @IBAction func launchTouched(_ sender: UIButton) {
        var config = Configuration()
        config.photoAlbumName = "SPCamera"

        let ctr = CameraViewController(configuration: config,
        onCancel: {
            self.dismiss(animated: true, completion: nil)
        }, onCapture: { (asset) in
            print("Captured asset")
        }, onFinish: { assets in
            print("Finished")
        })
        present(ctr, animated: true, completion: nil)
    }
}

