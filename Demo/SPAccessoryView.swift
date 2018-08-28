//
//  SPAccessoryView.swift
//  SPCamera
//
//  Created by Steven G Pint on 8/25/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit

class SPAccessoryView: UIInputView {

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
            containerView.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor, constant: 0).isActive = true
            containerView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor, constant: 0).isActive = true
        } else {
            containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0).isActive = true
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
}
