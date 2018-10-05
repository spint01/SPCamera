import UIKit

@objcMembers
open class TopContainerView: UIView {

    struct CompactDimensions {
        static let height: CGFloat = 0
    }
    var containerHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad || configuration.inlineMode {
            return 0
        } else {
            if DeviceType.IS_IPHONE_X_MAX {
                return 72
            } else if DeviceType.IS_IPHONE_X {
                return 34
            } else if DeviceType.IS_IPHONE_PLUS {
                return 50
            } else {
                return 42
            }
        }
    }

    var configuration = Configuration()

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
        backgroundColor = configuration.backgroundColor
        setupConstraints()

//        self.layer.borderColor = UIColor.yellow.cgColor
//        self.layer.borderWidth = 1.0
    }

    // MARK: - Action methods

    // MARK: - private methods

    private func setupConstraints() {

    }
}
