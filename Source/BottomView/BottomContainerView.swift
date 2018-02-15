import UIKit

@objc
protocol BottomContainerViewDelegate: class {

    func cameraButtonDidPress()
    func doneButtonDidPress()
    func cancelButtonDidPress()
}

@objcMembers
open class BottomContainerView: UIView {

    struct Dimensions {
        static let height: CGFloat = 120
    }
    struct CompactDimensions {
        static let height: CGFloat = 40
    }

    var configuration = Configuration()

    lazy var cameraButton: CameraButton = { [unowned self] in
        let button = CameraButton(configuration: self.configuration)
        button.setTitleColor(UIColor.white, for: UIControlState())
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
        button.setTitle(self.configuration.cancelButtonTitle, for: UIControlState())
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
    lazy var compassImageView: UIImageView = {
        let view = UIImageView(image: AssetManager.getImage("compass").withRenderingMode(.alwaysTemplate))
        view.tintColor = UIColor.white

        return view
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
            views = [compassImageView, borderCameraButton, cameraButton, doneButton, photoTitleLabel]
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

    // MARK: - public methods
    func rotateCompass(direction: Double) {
        let angle = CGFloat(direction).degreesToRadians
        print("photo direction: \(direction)  angle: \(angle)")
        compassImageView.transform = CGAffineTransform(rotationAngle: angle)
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

        // cameraButton
        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: self.centerXAnchor),
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
        if !configuration.inlineMode {
            // compassImageView
            NSLayoutConstraint.activate([
                compassImageView.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                compassImageView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 20)
                ])
            // doneButton
            NSLayoutConstraint.activate([
                doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                doneButton.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -20)
                ])
            // photoTitleLabel
            NSLayoutConstraint.activate([
                photoTitleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                photoTitleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 12)
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
