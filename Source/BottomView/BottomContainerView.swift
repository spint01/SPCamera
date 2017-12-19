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
        static let height: CGFloat = 101
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
        view.layer.borderWidth = configuration.compactMode ? CameraButton.CompactDimensions.borderWidth : CameraButton.Dimensions.borderWidth
        view.layer.cornerRadius = (configuration.compactMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize) / 2

        return view
    }()

    open lazy var doneButton: UIButton = { [unowned self] in
        let button = UIButton()
        button.setTitle(self.configuration.cancelButtonTitle, for: UIControlState())
        button.titleLabel?.font = self.configuration.doneButton
        button.addTarget(self, action: #selector(doneButtonDidPress(_:)), for: .touchUpInside)

        return button
    }()

    lazy var topSeparator: UIView = { [unowned self] in
        let view = UIView()
        view.backgroundColor = self.configuration.backgroundColor

        return view
    }()

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
        [borderCameraButton, cameraButton, doneButton, topSeparator].forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        backgroundColor = configuration.backgroundColor
        setupConstraints()
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
        var margins: UILayoutGuide!
        if #available(iOS 11.0, *) {
            margins = self.safeAreaLayoutGuide
        } else {
            margins = self.layoutMarginsGuide
        }

        // cameraButton
        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            cameraButton.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 0),
            cameraButton.widthAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize),
            cameraButton.heightAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize)
//            cameraButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: configuration.compactMode ? -20 : -20)
            ])
        // borderCameraButton
        NSLayoutConstraint.activate([
            borderCameraButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
            borderCameraButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            borderCameraButton.widthAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize),
            borderCameraButton.heightAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize)
            ])
        if !configuration.compactMode {
            // doneButton
            NSLayoutConstraint.activate([
                doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                doneButton.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -20)
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
