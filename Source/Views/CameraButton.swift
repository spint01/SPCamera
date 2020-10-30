import UIKit

class CameraButton: UIButton {

    enum Constants {
        fileprivate static let borderWidth: CGFloat = 4
        static let buttonSize: CGFloat = 54
        fileprivate static let buttonBorderSize: CGFloat = 68
    }

    private let outerView: UIView = UIView()

    var innerButtonColor: UIColor = .white {
        didSet {
            backgroundColor = innerButtonColor
        }
    }

  // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? innerButtonColor : .lightGray
        }
    }

    func commonInit() {
        layer.cornerRadius = Constants.buttonSize / 2

        outerView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(outerView, belowSubview: self)
        outerView.backgroundColor = UIColor.clear
        outerView.layer.borderColor = UIColor.white.cgColor
        outerView.layer.borderWidth = Constants.borderWidth
        outerView.layer.cornerRadius = Constants.buttonBorderSize / 2
        outerView.isUserInteractionEnabled = false

        // outerView
        NSLayoutConstraint.activate([
            outerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            outerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            outerView.widthAnchor.constraint(equalToConstant: Constants.buttonBorderSize),
            outerView.heightAnchor.constraint(equalToConstant: Constants.buttonBorderSize)
            ])

        accessibilityLabel = "Take photo"
    }
}
