//
//  SignInViewController.swift
//  SPCamera
//
//  Created by Steven G Pint on 8/27/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit

class SignInViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }


    @IBAction func signInTouched(_ sender: UIButton) {
        AppDelegate.displayMainScreen()
    }
}
