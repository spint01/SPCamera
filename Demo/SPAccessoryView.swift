//
//  SPAccessoryView.swift
//  SPCamera
//
//  Created by Steven G Pint on 8/25/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit

class SPAccessoryView: UIInputView {

    let ACCESSORY_HEIGHT: CGFloat = 50

    private lazy var textView: UITextView = { [unowned self] in
        let view = UITextView()
        view.backgroundColor = UIColor.white
        //        containerView.backgroundColor = UIColor(red: 242, green: 242, blue: 242) // default apple color
        //        view.debugBorder(UIColor.blue)
        view.cornerRadius = 12
        view.borderColor = UIColor.lightGray
        view.borderWidth = 1

        return view
    }()
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.cyan

        return view
    }()
    var accessoryViewHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect, inputViewStyle: UIInputViewStyle) {
        super.init(frame: frame, inputViewStyle: inputViewStyle)

        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        commonInit()
    }

    private func commonInit() {
        //        self.debugBorder(UIColor.brown, width: 3)
        backgroundColor = UIColor.yellow

        [containerView].forEach {
            self.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        [textView].forEach {
            containerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        setupConstraints()
    }

    private func setupConstraints() {

        // containerView
        NSLayoutConstraint.activate([
            ])
        if #available(iOS 11.0, *) {
            containerView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
            containerView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
            containerView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        } else {
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0).isActive = true
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0).isActive = true
        }

        // textView
        NSLayoutConstraint.activate([
            textView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 4),
            textView.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -4),
            textView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            textView.heightAnchor.constraint(equalToConstant: 40.0),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if accessoryViewHeightConstraint == nil {
            for constraint in constraints {
                if constraint.firstAttribute == .height {
                    accessoryViewHeightConstraint = constraint
                    if #available(iOS 11.0, *) {
                        accessoryViewHeightConstraint?.constant = ACCESSORY_HEIGHT + safeAreaInsets.bottom + 4
                    }
                    break
                }
            }
        } else {
            if #available(iOS 11.0, *) {
                accessoryViewHeightConstraint?.constant = ACCESSORY_HEIGHT + safeAreaInsets.bottom + 4
            }
        }
    }

    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        print("safeAreaInsets: \(safeAreaInsets)")

        setNeedsLayout()
    }
}
