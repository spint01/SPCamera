//
//  TabletOverlay.swift
//  SPCamera
//
//  Created by Steven G Pint on 10/27/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class TabletOverlay: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
    }
}
