//
//  DetailViewController.swift
//  SPCamera
//
//  Created by Steven G Pint on 8/27/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    lazy var accessoryView: SPAccessoryView = { [unowned self] in
        let view = SPAccessoryView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: ACCESSORY_HEIGHT))
        //        noteView.backgroundColor = self.navigationController?.navigationBar.backgroundColor
        //        noteView.backgroundColor = UIColor.yellow
        //        noteView.delegateAccessory = self

        return view
        }()
    let ACCESSORY_HEIGHT: CGFloat = 50
    var isKeyboardShowing = false

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.keyboardDismissMode = .interactive
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

            var contentInset = tableView.contentInset
            contentInset.bottom = keyboardFrame.height

            let diff = view.bounds.height - keyboardFrame.height - (navigationController?.navigationBar.frame.height ?? 0) - 44 //UIApplication.statusBarHeight()
            //            logv("diff: \(diff)")

            UIView.animate(withDuration: animationDuration) {
                self.tableView.contentInset = contentInset
                self.tableView.scrollIndicatorInsets = contentInset

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
        if #available(iOS 11.0, *) {
            print("safe area insets 3: \(view.safeAreaInsets) isKeyboardShowing: \(isKeyboardShowing)")
            self.accessoryView.accessoryViewHeightConstraint?.constant = ACCESSORY_HEIGHT + (isKeyboardShowing ? 0 : view.safeAreaInsets.bottom)
        } else {
            self.accessoryView.accessoryViewHeightConstraint?.constant = ACCESSORY_HEIGHT
        }
        print("setAccessoryHeight: \(self.accessoryView.accessoryViewHeightConstraint?.constant ?? 0)")
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

}
