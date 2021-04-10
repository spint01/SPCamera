//
//  CameraControlsOverlay.swift
//  SPCamera
//
//  Created by Steven G Pint on 10/27/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit
import CoreMedia

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
    func cameraModeButtonDidPress(_ mode: CameraMode)
    func doneButtonDidPress()
    func cancelButtonDidPress()
    func previewButtonDidPress()
    func locationButtonDidPress(_ isLocationAuthorized: Bool)
    func zoomButtonDidPress()
}

class CameraControlsOverlay {
    private enum Constant {
        static let topOffset: CGFloat = 5
        static let zoomButtonSize: CGFloat = 42
        static let accuracyButtonHeight: CGFloat = 35
        static let margins: CGFloat = 20
    }

    // Each device is slightly different in size
    static var bottomContainerViewHeight: CGFloat {
        guard !Helper.runningOnIpad else { return 100 }
        switch ScreenSize.SCREEN_MAX_LENGTH {
        case 896...10000: // IPHONE_X_MAX
            return 180
        case 812..<896: // IPHONE_X
            return 140
        case 736..<812: // IPHONE_PLUS
            return 130
        default:
            return 120
        }
    }
    private static var topContainerHeight: CGFloat {
        guard !Helper.runningOnIpad else { return 50 }
        switch ScreenSize.SCREEN_MAX_LENGTH {
        case 896...10000: // IPHONE_X_MAX
            return 74
        case 812..<896: // IPHONE_X
            return 34
        case 736..<812: // IPHONE_PLUS
            return 45
        default:
            return 42
        }
    }

    private let bottomContainerView: UIView = UIView()
    private let doneButton: UIButton = UIButton()
    private let photoPreviewButton: UIButton = UIButton()
    private let cameraModeButton: UIButton = UIButton()
    private let zoomButton: UIButton = UIButton()

    private let topContainerView: UIView = UIView()
    private let cameraButton: CameraButton = CameraButton()
    private let locationAuthorizationButton: UIButton = UIButton()
    private let compassView: CompassView = CompassView()
    private var cameraMode: CameraMode = .photo {
        didSet {
            cameraModeButton.setTitle(cameraMode.title, for: .normal)
            switch cameraMode {
            case .photo:
                cameraButton.innerButtonColor = .white
                cameraButton.setTitleColor(UIColor.white, for: .normal)
                cameraButton.setTitle(nil, for:.normal)
                videoDurationLabel.isHidden = true
                compassView.isHidden = !configuration.showCompass
            case .video:
                cameraButton.innerButtonColor = .red
                cameraButton.setTitleColor(UIColor.white, for: .normal)
                cameraButton.setTitle("Rec", for:.normal)
                videoDurationLabel.isHidden = false
                videoDuration(CMTime())
                compassView.isHidden = true
            }
        }
    }
    private lazy var videoDurationLabel: UIButton = {
        let button = UIButton()
        button.contentEdgeInsets = UIEdgeInsets(top: 1, left: 5, bottom: 1, right: 5)
        button.layer.cornerRadius = 2
        button.tintColor = .white
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .regular)
        button.isUserInteractionEnabled = false
        return button
    }()
    func videoDuration(_ duration: CMTime) {
        videoDurationLabel.setTitle(duration.positionalTime, for: .normal)
        videoDurationLabel.backgroundColor = duration.value > 0 ? .systemRed : .clear
        videoDurationLabel.setNeedsLayout()
    }

    private let cameraUnavailableLabel: UILabel = UILabel()
    private let photoLibUnavailableLabel: UILabel = UILabel()
    private let parentView: UIView
    private let configuration: Configuration

    // MARK: public variables

    var isCapturingPhoto: Bool = false {
        didSet {
            cameraButton.isEnabled = !isCapturingPhoto
        }
    }
    var isCapturingVideo: Bool = false {
        didSet {
            cameraButton.setTitle(isCapturingVideo ? "Stop" : "Rec", for: .normal)
        }
    }
    var isCameraAvailable: Bool = true {
        didSet {
            cameraUnavailableLabel.isHidden = isCameraAvailable
            zoomButton.isHidden = !isCameraAvailable
            cameraModeButton.isEnabled = configuration.isVideoAllowed && isCameraAvailable
            cameraButton.isEnabled = isCameraAvailable
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
    var isPreciseLocationAuthorized: Bool = true {
        didSet {
            updateLocationAuthorizationButtonText()
        }
    }
    var isLocationAuthorized: Bool = true {
        didSet {
            updateLocationAuthorizationButtonText()
        }
    }
    private func updateLocationAuthorizationButtonText() {
        locationAuthorizationButton.isHidden = isLocationAuthorized && isPreciseLocationAuthorized
        let isHidden = !locationAuthorizationButton.isHidden || !configuration.showCompass
        compassView.isHidden = isHidden
        let text: String = {
            if !isLocationAuthorized {
                return "Location Off  \(String("\u{276F}"))"
            }
            if !isPreciseLocationAuthorized {
                return "Precise Location: Off  \(String("\u{276F}"))"
            }
            return ""
        }()
        locationAuthorizationButton.setTitle(text, for: .normal)
    }

    weak var delegate: CameraOverlayDelegate?

    init(parentView: UIView, configuration: Configuration) {
        self.parentView = parentView
        self.configuration = configuration
        commonInit()
        setupUI()
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

        compassView.isHidden = configuration.showCompass

        topContainerView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(topContainerView)
        if Helper.runningOnIpad {
            topContainerView.backgroundColor = .clear
        }

        // locationAccuracyButton
        locationAuthorizationButton.translatesAutoresizingMaskIntoConstraints = false
        topContainerView.addSubview(locationAuthorizationButton)
        locationAuthorizationButton.layer.cornerRadius = 10
        locationAuthorizationButton.backgroundColor = UIColor.systemBlue
        locationAuthorizationButton.setTitle("Precise Location: Off  \(String("\u{276F}"))", for: .normal)
        locationAuthorizationButton.setTitleColor(UIColor.white, for: .normal)
        locationAuthorizationButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        locationAuthorizationButton.addTarget(self, action: #selector(locationAccuracyButtonDidPress), for: .touchUpInside)
        locationAuthorizationButton.isHidden = true

        videoDurationLabel.translatesAutoresizingMaskIntoConstraints = false
        topContainerView.addSubview(videoDurationLabel)
        videoDurationLabel.isHidden = true

        bottomContainerView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(bottomContainerView)

        // cameraModeButton
        cameraModeButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(cameraModeButton)
        cameraModeButton.backgroundColor = UIColor.clear
        cameraModeButton.setTitle(cameraMode.title, for: .normal)
        cameraModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
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
            topContainerView.heightAnchor.constraint(equalToConstant: CameraControlsOverlay.topContainerHeight)
        ])

        NSLayoutConstraint.activate([
            locationAuthorizationButton.centerXAnchor.constraint(equalTo: topContainerView.centerXAnchor),
            locationAuthorizationButton.centerYAnchor.constraint(equalTo: topContainerView.centerYAnchor),
            locationAuthorizationButton.heightAnchor.constraint(equalToConstant: Constant.accuracyButtonHeight)
            ])

        compassView.translatesAutoresizingMaskIntoConstraints = false
        topContainerView.addSubview(compassView)
        NSLayoutConstraint.activate([
            compassView.centerYAnchor.constraint(equalTo: topContainerView.centerYAnchor),
            compassView.rightAnchor.constraint(equalTo: topContainerView.rightAnchor, constant: -16),
        ])

        NSLayoutConstraint.activate([
            videoDurationLabel.centerXAnchor.constraint(equalTo: topContainerView.centerXAnchor),
            videoDurationLabel.topAnchor.constraint(equalTo: topContainerView.topAnchor, constant: 0),
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
            cameraModeButton.topAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: Constant.topOffset),
            cameraButton.centerXAnchor.constraint(equalTo: bottomContainerView.centerXAnchor),
            cameraButton.topAnchor.constraint(equalTo: cameraModeButton.bottomAnchor, constant: Self.bottomContainerViewHeight / 10),
            cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            doneButton.rightAnchor.constraint(equalTo: bottomContainerView.rightAnchor, constant: -Constant.margins),
            photoPreviewButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            photoPreviewButton.leftAnchor.constraint(equalTo: bottomContainerView.leftAnchor, constant: Constant.margins),
            photoPreviewButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            photoPreviewButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            zoomButton.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            zoomButton.bottomAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: -Constant.margins),
            zoomButton.widthAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
            zoomButton.heightAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
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
            locationAuthorizationButton.centerXAnchor.constraint(equalTo: topContainerView.centerXAnchor),
            locationAuthorizationButton.centerYAnchor.constraint(equalTo: topContainerView.centerYAnchor),
            locationAuthorizationButton.heightAnchor.constraint(equalToConstant: Constant.accuracyButtonHeight)
            ])

        NSLayoutConstraint.activate([
            videoDurationLabel.centerXAnchor.constraint(equalTo: topContainerView.centerXAnchor),
            videoDurationLabel.centerYAnchor.constraint(equalTo: topContainerView.centerYAnchor),
//            locationAuthorizationButton.heightAnchor.constraint(equalToConstant: Constant.accuracyButtonHeight)
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

        // compassStackView
        compassView.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(compassView)
        NSLayoutConstraint.activate([
            compassView.topAnchor.constraint(equalTo: doneButton.bottomAnchor, constant: 30),
            compassView.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
            compassView.rightAnchor.constraint(equalTo: topContainerView.rightAnchor, constant: -20),
        ])

        NSLayoutConstraint.activate([
            photoPreviewButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
            photoPreviewButton.bottomAnchor.constraint(equalTo: bottomContainerView.bottomAnchor, constant: -20),
            photoPreviewButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            photoPreviewButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
        ])
        NSLayoutConstraint.activate([
            zoomButton.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            zoomButton.rightAnchor.constraint(equalTo: bottomContainerView.leftAnchor, constant: -Constant.margins),
            zoomButton.widthAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
            zoomButton.heightAnchor.constraint(equalToConstant: Constant.zoomButtonSize)
        ])
        NSLayoutConstraint.activate([
            cameraUnavailableLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -64),
            photoLibUnavailableLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -64),
        ])
    }

    private func setupUI() {
        bottomContainerView.backgroundColor = configuration.bottomContainerViewColor.withAlphaComponent(0.10)
//        topContainerView.backgroundColor = configuration.bottomContainerViewColor.withAlphaComponent(0.10)
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

    // MARK: public methods

    func updateLocationAccuracyButton(_ isGray: Bool) {
        locationAuthorizationButton.backgroundColor = .clear
        locationAuthorizationButton.setTitleColor(.systemGray, for: .normal)
        locationAuthorizationButton.layoutIfNeeded()
    }

    // MARK: - public methods

    func rotateCompass(heading: Double) {
        guard configuration.showCompass, !isCapturingVideo else { return }
        compassView.rotateCompass(heading)
    }

    func photoPreviewTitle(_ title: String) {
        if title.count > 0 {
            let attribute = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 22),
                              NSAttributedString.Key.foregroundColor: UIColor.white]
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
        let attribute = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15, weight: .bold),
                          NSAttributedString.Key.foregroundColor: UIColor.white]
        zoomButton.setAttributedTitle(NSAttributedString(string: "\(factorStr)x", attributes: attribute), for: .normal)
    }

    // MARK: - Action methods

    @objc func cameraButtonDidPress(_ button: UIButton) {
        delegate?.cameraButtonDidPress(cameraMode)
    }

    @objc func cameraModeButtonDidPress(_ button: UIButton) {
        cameraMode = cameraMode == .photo ? .video : .photo
        delegate?.cameraModeButtonDidPress(cameraMode)
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
        delegate?.locationButtonDidPress(isLocationAuthorized)
    }
}
