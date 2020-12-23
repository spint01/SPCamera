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

protocol CameraOverlayDelegate: class {
    func cameraButtonDidPress(_ mode: CameraMode)
    func doneButtonDidPress()
    func cancelButtonDidPress()
    func previewButtonDidPress()
    func accuracyButtonDidPress()
    func zoomButtonDidPress()
}

class CameraOverlay {

    private enum Constant {
        static let topOffset: CGFloat = 10
        static let zoomButtonSize: CGFloat = 42
        static let accuracyButtonHeight: CGFloat = 35
    }

    // Each device is slightly different in size
    static var bottomContainerViewHeight: CGFloat {
        guard !Helper.runningOnIpad else { return 100 }
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

    static var topContainerHeight: CGFloat {
        guard !Helper.runningOnIpad else { return 50 }
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

    private let cameraUnavailableLabel: UILabel = UILabel()
    private let photoLibUnavailableLabel: UILabel = UILabel()

    weak var delegate: CameraOverlayDelegate?

    private let parentView: UIView
    private var configuration: Configuration = Configuration()

    // MARK: public variables

    var isCameraAvailable: Bool = true {
        didSet {
            cameraUnavailableLabel.isHidden = isCameraAvailable
            zoomButton.isHidden = !isCameraAvailable
            cameraModeButton.isEnabled = configuration.isVideoAllowed && isCameraAvailable
        }
    }
    var photoUnavailableText: String = "" {
        didSet {
            cameraUnavailableLabel.text = photoUnavailableText
            cameraUnavailableLabel.setNeedsLayout()
        }
    }
    var isPhotoLibraryAvailable: Bool = true {
        didSet {
            photoLibUnavailableLabel.isHidden = isPhotoLibraryAvailable
        }
    }

    init(parentView: UIView) {
        self.parentView = parentView
        commonInit()
    }

    private func commonInit() {
        // debug lines
//        topContainerView.layer.borderColor = UIColor.red.cgColor
//        topContainerView.layer.borderWidth = 1.0
//        bottomContainerView.layer.borderColor = UIColor.red.cgColor
//        bottomContainerView.layer.borderWidth = 1.0

        cameraUnavailableLabel.numberOfLines = 0
        cameraUnavailableLabel.textAlignment = .center
        cameraUnavailableLabel.isHidden = true

        photoLibUnavailableLabel.numberOfLines = 0
        photoLibUnavailableLabel.textAlignment = .center
        photoLibUnavailableLabel.backgroundColor = UIColor.black.withAlphaComponent(0.50)
        photoLibUnavailableLabel.isHidden = true

        topContainerView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(topContainerView)
        if Helper.runningOnIpad {
            topContainerView.backgroundColor = .clear
        }

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

        bottomContainerView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(bottomContainerView)

        // cameraModeButton
        cameraModeButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(cameraModeButton)
        cameraModeButton.backgroundColor = UIColor.clear
        cameraModeButton.setTitle(cameraMode.title, for: .normal)
        cameraModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.medium)
        cameraModeButton.addTarget(self, action: #selector(cameraModeButtonDidPress), for: .touchUpInside)

        // cameraButton
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(cameraButton)
        cameraButton.addTarget(self, action: #selector(cameraButtonDidPress), for: .touchUpInside)

        // doneButton
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(doneButton)

        // previewButton
        photoPreviewButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(photoPreviewButton)
        photoPreviewButton.addTarget(self, action: #selector(previewButtonDidPress), for: .touchUpInside)
        photoPreviewButton.layer.cornerRadius = 10

        // cameraUnavailableLabel
        cameraUnavailableLabel.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(cameraUnavailableLabel)
        NSLayoutConstraint.activate([
            cameraUnavailableLabel.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            cameraUnavailableLabel.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 32),
        ])

        // photoLibUnavailableLabel
        photoLibUnavailableLabel.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(photoLibUnavailableLabel)
        NSLayoutConstraint.activate([
            photoLibUnavailableLabel.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            photoLibUnavailableLabel.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 32),
        ])

        // zoomButton
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(zoomButton)
        zoomButton.addTarget(self, action: #selector(zoomButtonDidPress), for: .touchUpInside)
        zoomButton.layer.cornerRadius = Constant.zoomButtonSize / 2

        if Helper.runningOnIpad {
            setupTabletConstraints()
        } else {
            setupPhoneConstraints()
        }
    }

    private func setupPhoneConstraints() {
        let margins = parentView.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topContainerView.topAnchor.constraint(equalTo: margins.topAnchor),
            topContainerView.rightAnchor.constraint(equalTo: parentView.rightAnchor),
            topContainerView.leftAnchor.constraint(equalTo: parentView.leftAnchor),
            topContainerView.heightAnchor.constraint(equalToConstant: CameraOverlay.topContainerHeight)
        ])

        NSLayoutConstraint.activate([
            locationAccuracyButton.centerXAnchor.constraint(equalTo: topContainerView.centerXAnchor),
            locationAccuracyButton.topAnchor.constraint(equalTo: topContainerView.topAnchor, constant: 16),
            locationAccuracyButton.heightAnchor.constraint(equalToConstant: Constant.accuracyButtonHeight)
            ])

        // bottom
        NSLayoutConstraint.activate([
            bottomContainerView.leftAnchor.constraint(equalTo: parentView.leftAnchor),
            bottomContainerView.rightAnchor.constraint(equalTo: parentView.rightAnchor),
            bottomContainerView.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            bottomContainerView.heightAnchor.constraint(equalToConstant: Self.bottomContainerViewHeight)
        ])

        NSLayoutConstraint.activate([
            cameraModeButton.centerXAnchor.constraint(equalTo: bottomContainerView.centerXAnchor),
            cameraModeButton.topAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: Constant.topOffset)
        ])

        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: bottomContainerView.centerXAnchor),
            cameraButton.topAnchor.constraint(equalTo: cameraModeButton.bottomAnchor, constant: 20),
            cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
            ])
        NSLayoutConstraint.activate([
            doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            doneButton.rightAnchor.constraint(equalTo: bottomContainerView.rightAnchor, constant: -20)
            ])
        NSLayoutConstraint.activate([
            photoPreviewButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            photoPreviewButton.leftAnchor.constraint(equalTo: bottomContainerView.leftAnchor, constant: 20),
            photoPreviewButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            photoPreviewButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
            ])
        NSLayoutConstraint.activate([
            zoomButton.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            zoomButton.bottomAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: -20),
            zoomButton.widthAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
            zoomButton.heightAnchor.constraint(equalToConstant: Constant.zoomButtonSize)
        ])
        NSLayoutConstraint.activate([
            cameraUnavailableLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -32),
            photoLibUnavailableLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -32),
        ])
    }

    private func setupTabletConstraints() {
        NSLayoutConstraint.activate([
            topContainerView.topAnchor.constraint(equalTo: parentView.topAnchor),
            topContainerView.rightAnchor.constraint(equalTo: parentView.rightAnchor),
            topContainerView.leftAnchor.constraint(equalTo: parentView.leftAnchor),
            topContainerView.heightAnchor.constraint(equalToConstant: Self.topContainerHeight)
        ])

        NSLayoutConstraint.activate([
            locationAccuracyButton.centerXAnchor.constraint(equalTo: topContainerView.centerXAnchor),
            locationAccuracyButton.centerYAnchor.constraint(equalTo: topContainerView.centerYAnchor),
            locationAccuracyButton.heightAnchor.constraint(equalToConstant: Constant.accuracyButtonHeight)
            ])

        // bottom
        NSLayoutConstraint.activate([
            bottomContainerView.rightAnchor.constraint(equalTo: parentView.rightAnchor),
            bottomContainerView.topAnchor.constraint(equalTo: parentView.topAnchor),
            bottomContainerView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            bottomContainerView.widthAnchor.constraint(equalToConstant: Self.bottomContainerViewHeight)
        ])

        NSLayoutConstraint.activate([
            cameraModeButton.centerXAnchor.constraint(equalTo: bottomContainerView.centerXAnchor),
            cameraModeButton.bottomAnchor.constraint(equalTo: cameraButton.topAnchor, constant: -30)
        ])

        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: bottomContainerView.centerXAnchor),
            cameraButton.centerYAnchor.constraint(equalTo: bottomContainerView.centerYAnchor),
            cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
        ])
        NSLayoutConstraint.activate([
            doneButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
            doneButton.topAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: 20)
        ])
        NSLayoutConstraint.activate([
            photoPreviewButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
            photoPreviewButton.bottomAnchor.constraint(equalTo: bottomContainerView.bottomAnchor, constant: -20),
            photoPreviewButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            photoPreviewButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
        ])
        NSLayoutConstraint.activate([
            zoomButton.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            zoomButton.rightAnchor.constraint(equalTo: bottomContainerView.leftAnchor, constant: -20),
            zoomButton.widthAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
            zoomButton.heightAnchor.constraint(equalToConstant: Constant.zoomButtonSize)
        ])
        NSLayoutConstraint.activate([
            cameraUnavailableLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -64),
            photoLibUnavailableLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -64),
        ])
    }

    func configure(configuration: Configuration) {
        self.configuration = configuration
        bottomContainerView.backgroundColor =  configuration.bottomContainerViewColor.withAlphaComponent(0.10)
        cameraUnavailableLabel.textColor = configuration.noPermissionsTextColor
        cameraUnavailableLabel.text = configuration.cameraPermissionLabel
        photoLibUnavailableLabel.textColor = configuration.noPermissionsTextColor
        photoLibUnavailableLabel.text = configuration.photoPermissionLabel
        zoomButton.backgroundColor = configuration.bottomContainerViewColor.withAlphaComponent(0.40)
        cameraModeButton.setTitleColor(configuration.photoTypesLabelColor, for: .normal)

        if configuration.allowMultiplePhotoCapture {
            photoPreviewButton.isHidden = false
            doneButton.setTitle(configuration.doneButtonTitle, for: .normal)
            doneButton.addTarget(self, action: #selector(doneButtonDidPress), for: .touchUpInside)
        } else {
            photoPreviewButton.isHidden = true
            doneButton.setTitle(configuration.cancelButtonTitle, for: .normal)
            doneButton.addTarget(self, action: #selector(cancelButtonDidPress), for: .touchUpInside)
        }
        if !configuration.isVideoAllowed {
            cameraModeButton.isEnabled = false
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
