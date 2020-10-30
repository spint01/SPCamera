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
}

class PhoneOverlayView: UIView {

    private enum Constant {
        static let topOffset: CGFloat = 10
        static let zoomButtonSize: CGFloat = 42
    }

    // Each device is slightly different in size
    var bottomContainerHeight: CGFloat {
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

    let cameraButton: CameraButton = CameraButton()
    private let doneButton: UIButton = UIButton()
    private let photoPreviewButton: UIButton = UIButton()
    private let cameraModeButton: UIButton = UIButton()
    private let bottomContainer: UIView = UIView()
    private let zoomButton: UIButton = UIButton()

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
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomContainer)
        NSLayoutConstraint.activate([
            bottomContainer.leftAnchor.constraint(equalTo: leftAnchor),
            bottomContainer.rightAnchor.constraint(equalTo: rightAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomContainer.heightAnchor.constraint(equalToConstant: bottomContainerHeight)
        ])

        // cameraModeButton
        cameraModeButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(cameraModeButton)
        cameraModeButton.backgroundColor = UIColor.clear
        cameraModeButton.setTitle(cameraMode.title, for: .normal)
        cameraModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.medium)
        cameraModeButton.addTarget(self, action: #selector(cameraModeButtonDidPress), for: .touchUpInside)
        NSLayoutConstraint.activate([
            cameraModeButton.centerXAnchor.constraint(equalTo: bottomContainer.centerXAnchor),
            cameraModeButton.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: Constant.topOffset)
        ])

        // cameraButton
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(cameraButton)
        cameraButton.addTarget(self, action: #selector(cameraButtonDidPress), for: .touchUpInside)
        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: bottomContainer.centerXAnchor),
            cameraButton.topAnchor.constraint(equalTo: cameraModeButton.bottomAnchor, constant: 20),
            cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
            ])

        // doneButton
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(doneButton)
        NSLayoutConstraint.activate([
            doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            doneButton.rightAnchor.constraint(equalTo: bottomContainer.rightAnchor, constant: -20)
            ])

        // previewButton
        photoPreviewButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(photoPreviewButton)
        photoPreviewButton.addTarget(self, action: #selector(previewButtonDidPress), for: .touchUpInside)
        photoPreviewButton.layer.cornerRadius = 10
        NSLayoutConstraint.activate([
            photoPreviewButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            photoPreviewButton.leftAnchor.constraint(equalTo: bottomContainer.leftAnchor, constant: 20),
            photoPreviewButton.widthAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize),
            photoPreviewButton.heightAnchor.constraint(equalToConstant: CameraButton.Constants.buttonSize)
            ])

        // zoomButton
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(zoomButton)
        zoomButton.addTarget(self, action: #selector(zoomButtonDidPress), for: .touchUpInside)
        zoomButton.layer.cornerRadius = Constant.zoomButtonSize / 2
        // zoom button
        NSLayoutConstraint.activate([
            zoomButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            zoomButton.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: -20),
            zoomButton.widthAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
            zoomButton.heightAnchor.constraint(equalToConstant: Constant.zoomButtonSize)
        ])
    }

    func configure(configuration: Configuration) {
        backgroundColor = .clear // configuration.backgroundColor
        bottomContainer.backgroundColor = configuration.bottomContainerColor
        zoomButton.backgroundColor = configuration.bottomContainerColor.withAlphaComponent(0.40)
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
//        if !cameraUnavailableLabel.isHidden, !PhotoManager.shared.isSessionRunning { return }
//        zoomFactor(zoomFactor() == 1.0 ? 2.0 : 1.0)
    }
}
