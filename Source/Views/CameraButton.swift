import UIKit

protocol CameraButtonDelegate: class {

  func buttonDidPress(_ button: UIButton)
}

class CameraButton: UIButton {

    struct Dimensions {
        static let borderWidth: CGFloat = 4
        static let buttonSize: CGFloat = 54
        static let buttonBorderSize: CGFloat = 68
    }
    struct CompactDimensions {
        static let borderWidth: CGFloat = 2
        static let buttonSize: CGFloat = 25
        static let buttonBorderSize: CGFloat = 32
    }

    var configuration = Configuration()
    weak var delegate: CameraButtonDelegate?

  // MARK: - Initializers

    public init(configuration: Configuration? = nil) {
        if let configuration = configuration {
            self.configuration = configuration
        }
        super.init(frame: .zero)
        configure()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    func configure() {
        setupButton()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? .white : .lightGray
        }
    }

    func setupButton() {
        backgroundColor = UIColor.white
        layer.cornerRadius = configuration.inlineMode ? CompactDimensions.buttonSize / 2 : Dimensions.buttonSize / 2
        accessibilityLabel = "Take photo"
        addTarget(self, action: #selector(pickerButtonDidPress), for: .touchUpInside)
        addTarget(self, action: #selector(pickerButtonDidHighlight), for: .touchDown)
    }

    // MARK: - Actions

    @objc func pickerButtonDidPress(_ button: UIButton) {
        backgroundColor = UIColor.white
        delegate?.buttonDidPress(button)
    }

    @objc func pickerButtonDidHighlight(_ button: UIButton) {
        backgroundColor = UIColor(red:0.3, green:0.3, blue:0.3, alpha:1)
    }
}
