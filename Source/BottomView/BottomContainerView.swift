import UIKit

@objc
protocol BottomContainerViewDelegate: class {

    func cameraButtonDidPress()
    func doneButtonDidPress()
    func cancelButtonDidPress()
}

@objcMembers
open class BottomContainerView: UIView {

    struct CompactDimensions {
        static let height: CGFloat = 40
    }
    var containerHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad || configuration.inlineMode {
            return 120
        } else {
            if DeviceType.IS_IPHONE_X_MAX {
                return 190
            } else if DeviceType.IS_IPHONE_X {
                return 140
            } else if DeviceType.IS_IPHONE_PLUS {
                return 140
            } else {
                return 130
            }
        }
    }

    var configuration = Configuration()

    lazy var cameraButton: CameraButton = { [unowned self] in
        let button = CameraButton(configuration: self.configuration)
        button.setTitleColor(UIColor.white, for: UIControl.State())
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
    open lazy var doneButton: UIButton = { [unowned self] in
        let button = UIButton()
        button.setTitle(self.configuration.cancelButtonTitle, for: UIControl.State())
        button.addTarget(self, action: #selector(doneButtonDidPress(_:)), for: .touchUpInside)

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

    func configure() {
        var views: [UIView]
        if configuration.inlineMode {
            views = [borderCameraButton, cameraButton]
        } else {
            views = [borderCameraButton, cameraButton, doneButton, photoTitleLabel]
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
        if button.currentTitle == configuration.cancelButtonTitle {
            delegate?.cancelButtonDidPress()
        } else {
            delegate?.doneButtonDidPress()
        }
    }

    // MARK: - private methods

    private func setupConstraints() {
//        var margins: UILayoutGuide!
//        if #available(iOS 11.0, *) {
//            margins = self.safeAreaLayoutGuide
//        } else {
//            margins = self.layoutMarginsGuide
//        }

        if !configuration.inlineMode {
            if Helper.runningOnIpad {
                // cameraButton
                NSLayoutConstraint.activate([
                    cameraButton.centerXAnchor.constraint(equalTo: self.centerXAnchor, constant: Helper.runningOnIpad && !configuration.inlineMode ? 15 : 0),
                    cameraButton.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: configuration.inlineMode ? 0 : 14),
                    cameraButton.widthAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize),
                    cameraButton.heightAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize)
                    //            cameraButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: configuration.inlineMode ? -20 : -20)
                    ])
                // borderCameraButton
                NSLayoutConstraint.activate([
                    borderCameraButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
                    borderCameraButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                    borderCameraButton.widthAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize),
                    borderCameraButton.heightAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize)
                    ])
                // doneButton
                NSLayoutConstraint.activate([
                    doneButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
                    doneButton.topAnchor.constraint(equalTo: self.topAnchor, constant: 20)
                    ])
                // photoTitleLabel
                photoTitleLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
                NSLayoutConstraint.activate([
                    photoTitleLabel.rightAnchor.constraint(equalTo: borderCameraButton.leftAnchor, constant: 5),
                    photoTitleLabel.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor)
                    ])
            } else {
                // cameraButton
                NSLayoutConstraint.activate([
                    cameraButton.centerXAnchor.constraint(equalTo: self.centerXAnchor, constant: Helper.runningOnIpad && !configuration.inlineMode ? 15 : 0),
                    cameraButton.topAnchor.constraint(equalTo: photoTitleLabel.bottomAnchor, constant: 20),
                    cameraButton.widthAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize),
                    cameraButton.heightAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize)
                    //            cameraButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: configuration.inlineMode ? -20 : -20)
                    ])
                // borderCameraButton
                NSLayoutConstraint.activate([
                    borderCameraButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
                    borderCameraButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                    borderCameraButton.widthAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize),
                    borderCameraButton.heightAnchor.constraint(equalToConstant: configuration.inlineMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize)
                    ])
                // doneButton
                NSLayoutConstraint.activate([
                    doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                    doneButton.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -20)
                    ])
                // photoTitleLabel
                NSLayoutConstraint.activate([
                    photoTitleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                    photoTitleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 10)
                    ])
            }
        }
    }
}

// MARK: - ButtonPickerDelegate methods

extension BottomContainerView: CameraButtonDelegate {

    func buttonDidPress() {
        delegate?.cameraButtonDidPress()
    }
}
