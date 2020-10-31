//
//  PhoneOverlay.swift
//  SPCamera
//
//  Created by Steven G Pint on 10/27/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

enum CameraMode {
    case photo
    case video

    var title: String {
        switch self {
        case .photo: return "PHOTO"
        case .video: return "VIDEO"
        }
    }
}

protocol PhoneOverlayViewDelegate: class {
    func cameraButtonDidPress(_ mode: CameraMode)
    func doneButtonDidPress()
    func cancelButtonDidPress()
    func previewButtonDidPress()
    func accuracyButtonDidPress()
    func zoomButtonDidPress()
}

class PhoneOverlayView: UIView {

    private enum Constant {
        static let topOffset: CGFloat = 10
        static let zoomButtonSize: CGFloat = 42
        static let accuracyButtonHeight: CGFloat = 35
    }

    // Each device is slightly different in size
    var bottomContainerViewHeight: CGFloat {
        if ScreenSize.SCREEN_MAX_LENGTH >= 896.0 { // IPHONE_X_MAX
            return 180
        } else if ScreenSize.SCREEN_MAX_LENGTH >= 812.0 { // IPHONE_X
            return 140
        } else if ScreenSize.SCREEN_MAX_LENGTH >= 736.0 { // IPHONE_PLUS
            return 130
        } else {
            return 120
        }
    }
    private let bottomContainerView: UIView = UIView()
    let cameraButton: CameraButton = CameraButton()
    private let doneButton: UIButton = UIButton()
    private let photoPreviewButton: UIButton = UIButton()
    private let cameraModeButton: UIButton = UIButton()
    private let zoomButton: UIButton = UIButton()

    var topContainerHeight: CGFloat {
        if ScreenSize.SCREEN_MAX_LENGTH >= 896.0 { // IPHONE_X_MAX
            return 74
        } else if ScreenSize.SCREEN_MAX_LENGTH >= 812.0 { // IPHONE_X
            return 34
        } else if ScreenSize.SCREEN_MAX_LENGTH >= 736.0 { // IPHONE_PLUS
            return 45
        } else {
            return 42
        }
    }
    private let topContainerView: UIView = UIView()
    let locationAccuracyButton: UIButton = UIButton()

    private var cameraMode: CameraMode = .photo {
        didSet {
            cameraModeButton.setTitle(cameraMode.title, for: .normal)

            switch cameraMode {
            case .photo:
                cameraButton.innerButtonColor = .white
                cameraButton.setTitleColor(UIColor.white, for: .normal)
                cameraButton.setTitle(nil, for:.normal)
            case .video:
                cameraButton.innerButtonColor = .red
                cameraButton.setTitleColor(UIColor.white, for: .normal)
                cameraButton.setTitle("Rec", for:.normal)
            }
        }
    }

    weak var delegate: PhoneOverlayViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        topContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topContainerView)
        NSLayoutConstraint.activate([
            topContainerView.topAnchor.constraint(equalTo: topAnchor),
            topContainerView.rightAnchor.constraint(equalTo: rightAnchor),
            topContainerView.leftAnchor.constraint(equalTo: leftAnchor),
            topContainerView.heightAnchor.constraint(equalToConstant: topContainerHeight)
        ])

        // locationAccuracyButton
        locationAccuracyButton.translatesAutoresizingMaskIntoConstraints = false
        topContainerView.addSubview(locationAccuracyButton)
        locationAccuracyButton.layer.cornerRadius = 10
        locationAccuracyButton.backgroundColor = UIColor.systemBlue
        locationAccuracyButton.setTitle("Precise Location: Off  \(String("\u{276F}"))", for: .normal)
        locationAccuracyButton.setTitleColor(UIColor.white, for: .normal)
        locationAccuracyButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        locationAccuracyButton.addTarget(self, action: #selector(locationAccuracyButtonDidPress), for: .touchUpInside)
        locationAccuracyButton.isHidden = true
        NSLayoutConstraint.activate([
            locationAccuracyButton.centerXAnchor.constraint(equalTo: topContainerView.centerXAnchor),
            locationAccuracyButton.topAnchor.constraint(equalTo: topContainerView.topAnchor, constant: 16),
            locationAccuracyButton.heightAnchor.constraint(equalToConstant: Constant.accuracyButtonHeight)
            ])

        bottomContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomContainerView)
        NSLayoutConstraint.activate([
            bottomContainerView.leftAnchor.constraint(equalTo: leftAnchor),
            bottomContainerView.rightAnchor.constraint(equalTo: rightAnchor),
            bottomContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomContainerView.heightAnchor.constraint(equalToConstant: bottomContainerViewHeight)
        ])

        // cameraModeButton
        cameraModeButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(cameraModeButton)
        cameraModeButton.backgroundColor = UIColor.clear
        cameraModeButton.setTitle(cameraMode.title, for: .normal)
        cameraModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.medium)
        cameraModeButton.addTarget(self, action: #selector(cameraModeButtonDidPress), for: .touchUpInside)
        NSLayoutConstraint.activate([
            cameraModeButton.centerXAnchor.constraint(equalTo: bottomContainerView.centerXAnchor),
            cameraModeButton.topAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: Constant.topOffset)
        ])

        // cameraButton
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(cameraButton)
        cameraButton.addTarget(self, action: #selector(cameraButtonDidPress), for: .touchUpInside)
        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: bottomContainerView.centerXAnchor),
            cameraButton.topAnchor.constraint(equalTo: cameraModeButton.bottomAnchor, constant: 20),
            cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
            ])

        // doneButton
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(doneButton)
        NSLayoutConstraint.activate([
            doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            doneButton.rightAnchor.constraint(equalTo: bottomContainerView.rightAnchor, constant: -20)
            ])

        // previewButton
        photoPreviewButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(photoPreviewButton)
        photoPreviewButton.addTarget(self, action: #selector(previewButtonDidPress), for: .touchUpInside)
        photoPreviewButton.layer.cornerRadius = 10
        NSLayoutConstraint.activate([
            photoPreviewButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            photoPreviewButton.leftAnchor.constraint(equalTo: bottomContainerView.leftAnchor, constant: 20),
            photoPreviewButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            photoPreviewButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
            ])

        // zoomButton
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(zoomButton)
        zoomButton.addTarget(self, action: #selector(zoomButtonDidPress), for: .touchUpInside)
        zoomButton.layer.cornerRadius = Constant.zoomButtonSize / 2
        NSLayoutConstraint.activate([
            zoomButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            zoomButton.bottomAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: -20),
            zoomButton.widthAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
            zoomButton.heightAnchor.constraint(equalToConstant: Constant.zoomButtonSize)
        ])

//        topContainerView.layer.borderColor = UIColor.red.cgColor
//        topContainerView.layer.borderWidth = 1.0
//        bottomContainerView.layer.borderColor = UIColor.red.cgColor
//        bottomContainerView.layer.borderWidth = 1.0
    }

    func configure(configuration: Configuration) {
        backgroundColor = .clear // configuration.backgroundColor
        bottomContainerView.backgroundColor = configuration.bottomContainerViewColor
        zoomButton.backgroundColor = configuration.bottomContainerViewColor.withAlphaComponent(0.40)
        cameraModeButton.setTitleColor(configuration.photoTypesLabelColor, for: .normal)

        if configuration.allowMultiplePhotoCapture {
            photoPreviewButton.isHidden = true
            doneButton.setTitle(configuration.doneButtonTitle, for: .normal)
            doneButton.addTarget(self, action: #selector(doneButtonDidPress), for: .touchUpInside)
        } else {
            doneButton.setTitle(configuration.cancelButtonTitle, for: .normal)
            doneButton.addTarget(self, action: #selector(cancelButtonDidPress), for: .touchUpInside)
        }
    }

    func updateLocationAccuracyButton(_ isGray: Bool) {
        locationAccuracyButton.backgroundColor = .clear
        locationAccuracyButton.setTitleColor(.systemGray, for: .normal)
        locationAccuracyButton.layoutIfNeeded()
    }

    func photoPreviewTitle(_ title: String) {
        if title.count > 0 {
            let attribute = [ NSAttributedString.Key.font: UIFont.systemFont(ofSize: 22),
                              NSAttributedString.Key.foregroundColor: UIColor.white ]
            photoPreviewButton.setAttributedTitle(NSAttributedString(string: title, attributes: attribute), for: .normal)
            photoPreviewButton.layer.borderColor = UIColor.white.cgColor
            photoPreviewButton.layer.borderWidth = 1.0
        } else {
            photoPreviewButton.setTitle("", for: .normal)
            photoPreviewButton.layer.borderWidth = 0.0
        }
    }

    func updateZoomButtonTitle(_ zoom: CGFloat) {
        var factorStr = String(format: "%.1f", zoom)
        if factorStr.hasSuffix(".0") {
            // don't show trailing .0
            factorStr = String(factorStr.dropLast(2))
        }
        let attribute = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14, weight: .medium),
                          NSAttributedString.Key.foregroundColor: UIColor.white]
        zoomButton.setAttributedTitle(NSAttributedString(string: "\(factorStr)x", attributes: attribute), for: .normal)
    }

    // MARK: - Action methods

    @objc func cameraButtonDidPress(_ button: UIButton) {
        delegate?.cameraButtonDidPress(cameraMode)
    }

    @objc func cameraModeButtonDidPress(_ button: UIButton) {
        cameraMode = cameraMode == .photo ? .video : .photo
    }

    @objc func doneButtonDidPress(_ button: UIButton) {
        delegate?.doneButtonDidPress()
    }

    @objc func cancelButtonDidPress(_ button: UIButton) {
        delegate?.cancelButtonDidPress()
    }

    @objc func previewButtonDidPress(_ button: UIButton) {
        delegate?.previewButtonDidPress()
    }

    @objc func zoomButtonDidPress(_ button: UIButton) {
        delegate?.zoomButtonDidPress()
    }

    @objc private func locationAccuracyButtonDidPress() {
        delegate?.accuracyButtonDidPress()
    }
}
