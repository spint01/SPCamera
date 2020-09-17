import UIKit

protocol TopContainerViewDelegate: class {
  func accuracyButtonDidPress()
}

@objcMembers
open class TopContainerView: UIView {

    struct AccuracyButton {
        static let buttonHeight: CGFloat = 35
    }
    struct CompactDimensions {
        static let height: CGFloat = 0
    }
    var containerHeight: CGFloat {
        if Helper.runningOnIpad || configuration.inlineMode {
            return 50
        } else {
            if DeviceType.IS_IPHONE_X_MAX {
                return 74
            } else if DeviceType.IS_IPHONE_X {
                return 34
            } else if DeviceType.IS_IPHONE_PLUS {
                return 45
            } else {
                return 42
            }
        }
    }
    lazy var locationAccuracyButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 10
        button.backgroundColor = UIColor.systemBlue
        button.setTitle("Precise Location: Off  \(String("\u{276F}"))", for: .normal)
        button.setTitleColor(UIColor.white, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        button.addTarget(self, action: #selector(locationAccuracyButtonDidPress), for: .touchUpInside)
        button.isHidden = true

        return button
    }()

    var configuration = Configuration()
    weak var delegate: TopContainerViewDelegate?

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

    private func configure() {
        backgroundColor = Helper.runningOnIpad ? UIColor.clear : configuration.backgroundColor
        let views = [locationAccuracyButton]
        views.forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        setupConstraints()

//        self.layer.borderColor = UIColor.yellow.cgColor
//        self.layer.borderWidth = 1.0
    }

    // MARK: - public methods

    func updateLocationAccuracyButton(_ isGray: Bool) {
        locationAccuracyButton.backgroundColor = .clear
        locationAccuracyButton.setTitleColor(.systemGray, for: .normal)
        locationAccuracyButton.layoutIfNeeded()
    }

    // MARK: - Action methods

    @objc private func locationAccuracyButtonDidPress() {
        delegate?.accuracyButtonDidPress()
    }

    // MARK: - private methods

    private func setupConstraints() {
        if !configuration.inlineMode {
            if Helper.runningOnIpad {
                // locationAccuracyButton
                NSLayoutConstraint.activate([
                    locationAccuracyButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                    locationAccuracyButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
                    locationAccuracyButton.heightAnchor.constraint(equalToConstant: AccuracyButton.buttonHeight)
                    ])
            } else {
                NSLayoutConstraint.activate([
                    locationAccuracyButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                    locationAccuracyButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
                    locationAccuracyButton.heightAnchor.constraint(equalToConstant: AccuracyButton.buttonHeight)
                    ])
            }
        }
    }
}
