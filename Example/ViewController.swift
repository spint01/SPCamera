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

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func launchTouched(_ sender: UIButton) {
//        var config = Configuration()
//        config.photoAlbumName = "SPCamera"

//        let ctr = CameraViewController(configuration: config)
//        ctr.delegate = self
//        //    ctr.modalPresentationCapturesStatusBarAppearance = true
//        present(ctr, animated: true, completion: nil)

        let ctr = CameraViewController()
        present(ctr, animated: true, completion: nil)
    }
}

