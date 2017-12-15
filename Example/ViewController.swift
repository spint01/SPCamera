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

        containerView.backgroundColor = UIColor.yellow

        let ctr = CameraViewController()
        ctr.compactMode = true
        addChildViewController(ctr)
        containerView.addSubview(ctr.view)
        ctr.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ctr.view.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 0),
            ctr.view.widthAnchor.constraint(equalToConstant: 110),
            ctr.view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0),
            ctr.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0)
            ])

        ctr.didMove(toParentViewController: self)
        //containerView.addSubview(ctr.view)
    }

    @IBAction func launchTouched(_ sender: UIButton) {
//        var config = Configuration()
//        config.photoAlbumName = "SPCamera"


        let ctr = CameraViewController()
        present(ctr, animated: true, completion: nil)
    }
}

