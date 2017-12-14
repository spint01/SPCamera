import UIKit

protocol CameraButtonDelegate: class {

  func buttonDidPress()
}

class CameraButton: UIButton {

  struct Dimensions {
    static let borderWidth: CGFloat = 2
    static let buttonSize: CGFloat = 58
    static let buttonBorderSize: CGFloat = 68
  }

  weak var delegate: CameraButtonDelegate?

  // MARK: - Initializers

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

  func setupButton() {
    backgroundColor = UIColor.white
    layer.cornerRadius = Dimensions.buttonSize / 2
    accessibilityLabel = "Take photo"
    addTarget(self, action: #selector(pickerButtonDidPress(_:)), for: .touchUpInside)
    addTarget(self, action: #selector(pickerButtonDidHighlight(_:)), for: .touchDown)
  }

  // MARK: - Actions

  @objc func pickerButtonDidPress(_ button: UIButton) {
    backgroundColor = UIColor.white
    delegate?.buttonDidPress()
  }

  @objc func pickerButtonDidHighlight(_ button: UIButton) {
    backgroundColor = UIColor(red:0.3, green:0.3, blue:0.3, alpha:1)
  }
}
