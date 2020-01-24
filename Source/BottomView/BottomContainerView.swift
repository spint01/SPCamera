import UIKit

@objc
protocol BottomContainerViewDelegate: class {

    func cameraButtonDidPress()
    func doneButtonDidPress()
    func cancelButtonDidPress()
    func previewButtonDidPress()
}

@objcMembers
open class BottomContainerView: UIView {

    struct CompactDimensions {
        static let height: CGFloat = 40
    }
    // Each device is slightly different in size
    var containerHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad || configuration.inlineMode {
            return 120
        } else {
            if DeviceType.IS_IPHONE_X_MAX {
                return 180
            } else if DeviceType.IS_IPHONE_X {
                return 140
            } else if DeviceType.IS_IPHONE_PLUS {
                return 130
            } else {
                return 120
            }
        }
    }
    // Each device is slightly different in size
    var topOffset: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad || configuration.inlineMode {
            return 0
        } else {
            if DeviceType.IS_IPHONE_X_MAX {
                return 15
            } else if DeviceType.IS_IPHONE_X {
                return 5
            } else if DeviceType.IS_IPHONE_PLUS {
                return 15
            } else {
                return 10
            }
        }
    }

    var configuration = Configuration()

    lazy var cameraButton: CameraButton = { [unowned self] in
        let button = CameraButton(configuration: self.configuration)
        button.setTitleColor(UIColor.white, for: .normal)
        button.delegate = self

        return button
        }()

    lazy var borderCameraButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = configuration.inlineMode ? CameraButton.CompactDimensions.borderWidth : CameraButton.Dimensions.borderWidth
        view.layer.cornerRadius = (configuration.inlineMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize) / 2

        return view
    }()
    lazy var doneButton: UIButton = { [unowned self] in
        let button = UIButton()
        if  self.configuration.allowMultiplePhotoCapture {
            button.setTitle(self.configuration.doneButtonTitle, for: .normal)
            button.addTarget(self, action: #selector(doneButtonDidPress(_:)), for: .touchUpInside)
        } else {
            button.setTitle(self.configuration.cancelButtonTitle, for: .normal)
            button.addTarget(self, action: #selector(cancelButtonDidPress(_:)), for: .touchUpInside)
        }

        return button
    }()
    lazy var photoTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.clear
        label.textColor = configuration.photoTypesLabelColor
        label.text = "PHOTO"
        label.font = UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.medium)

        return label
    }()
    lazy var previewButton: UIButton = { [unowned self] in
        let button = UIButton()
        button.addTarget(self, action: #selector(previewButtonDidPress(_:)), for: .touchUpInside)
        button.layer.cornerRadius = 10

//        button.layer.borderColor = UIColor.red.cgColor
//        button.layer.borderWidth = 1.0
        return button
    }()

//    lazy var topSeparator: UIView = { [unowned self] in
//        let view = UIView()
//        view.backgroundColor = self.configuration.backgroundColor
//
//        return view
//    }()

    weak var delegate: BottomContainerViewDelegate?

  // MARK: Initializers

    public init(configuration: Configuration? = nil) {
        if let configuration = configuration {
            self.configuration = configuration
        }
        super.init(frame: .zero)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func previewTitle(_ title: String) {
        if title.count > 0 {
            let attribute = [ NSAttributedString.Key.font: UIFont.systemFont(ofSize: 22),
                              NSAttributedString.Key.foregroundColor: UIColor.white ]
            previewButton.setAttributedTitle(NSAttributedString(string: title, attributes: attribute), for: .normal)
            previewButton.layer.borderColor = UIColor.white.cgColor
            previewButton.layer.borderWidth = 1.0
        } else {
            previewButton.setTitle("", for: .normal)
            previewButton.layer.borderWidth = 0.0
        }
    }

    private func configure() {
        var views: [UIView]
        if configuration.inlineMode {
            views = [borderCameraButton, cameraButton]
        } else {
            views = [borderCameraButton, cameraButton, doneButton, photoTitleLabel, previewButton]
        }
        views.forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        backgroundColor = configuration.backgroundColor
        setupConstraints()

//        self.layer.borderColor = UIColor.red.cgColor
//        self.layer.borderWidth = 1.0
    }

    // MARK: - Action methods

    @objc func doneButtonDidPress(_ button: UIButton) {
        delegate?.doneButtonDidPress()
    }

    @objc func cancelButtonDidPress(_ button: UIButton) {
        delegate?.cancelButtonDidPress()
    }

    @objc func previewButtonDidPress(_ button: UIButton) {
        delegate?.previewButtonDidPress()
    }

    // MARK: - private methods

    private func setupConstraints() {
        if !configuration.inlineMode {
            if Helper.runningOnIpad {
                // cameraButton
                NSLayoutConstraint.activate([
                    cameraButton.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 15),
                    cameraButton.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0),
                    cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize),
                    cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize)
                    ])
                // borderCameraButton
                NSLayoutConstraint.activate([
                    borderCameraButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
                    borderCameraButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                    borderCameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonBorderSize),
                    borderCameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonBorderSize)
                    ])
                // doneButton
                NSLayoutConstraint.activate([
                    doneButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor, constant: -10),
                    doneButton.topAnchor.constraint(equalTo: topAnchor, constant: 20)
                    ])
                // previewButton
                NSLayoutConstraint.activate([
                    previewButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
                    previewButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
                    previewButton.widthAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize),
                    previewButton.heightAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize)
                    ])
                // photoTitleLabel
                photoTitleLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
                NSLayoutConstraint.activate([
                    photoTitleLabel.rightAnchor.constraint(equalTo: borderCameraButton.leftAnchor, constant: 5),
                    photoTitleLabel.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor)
                    ])
            } else {
                // iPhone
                // cameraButton
                NSLayoutConstraint.activate([
                    cameraButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                    cameraButton.topAnchor.constraint(equalTo: photoTitleLabel.bottomAnchor, constant: 20),
                    cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize),
                    cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize)
                    ])
                // borderCameraButton
                NSLayoutConstraint.activate([
                    borderCameraButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
                    borderCameraButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                    borderCameraButton.widthAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonBorderSize),
                    borderCameraButton.heightAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonBorderSize)
                    ])
                // doneButton
                NSLayoutConstraint.activate([
                    doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                    doneButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -20)
                    ])
                // previewButton
                NSLayoutConstraint.activate([
                    previewButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                    previewButton.leftAnchor.constraint(equalTo: leftAnchor, constant: 20),
                    previewButton.widthAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize),
                    previewButton.heightAnchor.constraint(equalToConstant: CameraButton.Dimensions.buttonSize)
                    ])
                // photoTitleLabel
                NSLayoutConstraint.activate([
                    photoTitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                    photoTitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: topOffset)
                    ])
            }
        } else {
            // cameraButton
            NSLayoutConstraint.activate([
                cameraButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                cameraButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                cameraButton.widthAnchor.constraint(equalToConstant: CameraButton.CompactDimensions.buttonSize),
                cameraButton.heightAnchor.constraint(equalToConstant: CameraButton.CompactDimensions.buttonSize)
                ])
            // borderCameraButton
            NSLayoutConstraint.activate([
                borderCameraButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
                borderCameraButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                borderCameraButton.widthAnchor.constraint(equalToConstant: CameraButton.CompactDimensions.buttonBorderSize),
                borderCameraButton.heightAnchor.constraint(equalToConstant: CameraButton.CompactDimensions.buttonBorderSize)
                ])
        }
    }
}

// MARK: - ButtonPickerDelegate methods

extension BottomContainerView: CameraButtonDelegate {

    func buttonDidPress() {
        delegate?.cameraButtonDidPress()
    }
}
