//
//  CompassView.swift
//  SPCamera
//
//  Created by Steven G Pint on 4/8/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import UIKit

class CompassView: UIView {
    private enum Constant {
        static let compassLabelWidth: CGFloat = 45
    }
    private lazy var compassArrowImageView: UIImageView = UIImageView(image: AssetManager.image(named: "compass_arrow"))
    private lazy var compassLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.50
        return label
    }()

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        compassArrowImageView.isHidden = true
        compassLabel.isHidden = true
        compassArrowImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(compassArrowImageView)
        compassLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(compassLabel)
        NSLayoutConstraint.activate([
            compassArrowImageView.widthAnchor.constraint(equalToConstant: 30),
            compassArrowImageView.heightAnchor.constraint(equalToConstant: 30),
            compassLabel.widthAnchor.constraint(equalToConstant: Constant.compassLabelWidth),
        ])

        if Helper.runningOnIpad {
            NSLayoutConstraint.activate([
                compassArrowImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                compassArrowImageView.topAnchor.constraint(equalTo: topAnchor),
                compassLabel.topAnchor.constraint(equalTo: compassArrowImageView.bottomAnchor, constant: 15),
                compassLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                compassArrowImageView.rightAnchor.constraint(equalTo: rightAnchor),
                compassLabel.rightAnchor.constraint(equalTo: compassArrowImageView.leftAnchor, constant: -15),
                compassLabel.topAnchor.constraint(equalTo: topAnchor, constant: -15),
                compassArrowImageView.centerYAnchor.constraint(equalTo: compassLabel.centerYAnchor),
            ])
        }
    }

    private var rotationAdjustment: CGFloat {
        guard !Helper.runningOnIpad else { return 0 }
        switch UIDevice.current.orientation {
            case .landscapeLeft:
                return -90
            case .landscapeRight:
                return 90
            case .portraitUpsideDown:
                return 180
            default: return 0 // .portrait, .faceDown, .faceUp
        }
    }

    private func rotateArrow(_ heading: Double) {
        let degrees = CGFloat(heading.headingAdjusted) + rotationAdjustment
        let angle: CGFloat = degrees.degreesToRadians
        compassArrowImageView.transform = CGAffineTransform(rotationAngle: -angle)
    }

    // MARK: public methods

    func rotateCompass(_ heading: Double) {
        UIView.animate(withDuration: 0.3) {
            self.rotateArrow(heading)
            let adjusted = heading.headingAdjusted
            self.compassLabel.text = "\(String(format: "%.0f%@\n%@", adjusted, Helper.DEGREES, adjusted.direction.description))"
            guard !Helper.runningOnIpad else { return }
            let textAngle: CGFloat = CGFloat(self.rotationAdjustment).degreesToRadians
            self.compassLabel.transform = CGAffineTransform(rotationAngle: -textAngle)
        } completion: { (finished) in
            self.compassArrowImageView.isHidden = false
            self.compassLabel.isHidden = false
        }
    }
}
