//
//  CircularAnimatable.swift
//  EyeTrackingTest
//
//  Created by Kyle Ohanian on 4/17/19.
//  Copyright © 2019 WillowTree. All rights reserved.
//

import UIKit

protocol CircularAnimatable {
    var animationView: UIView { get }
    var animationViewDiameter: CGFloat { get }
    var hoverBorderColor: UIColor? { get set }
    var statelessBorderColor: UIColor? { get set }
}

extension CircularAnimatable where Self: TrackingView {
    var animationViewDiameter: CGFloat {
        let height = self.frame.height
        let width = self.frame.width
        let requiredDiameter = sqrt(height * height + width * width)
        return requiredDiameter
    }
    func animateGaze() {
        if self.isTrackingEnabled {
            self.invalidateAnimationView()
            self.layoutIfNeeded()
            self.animationView.isHidden = false
            self.layer.borderColor = self.hoverBorderColor?.cgColor
            UIView.animate(withDuration: self.animationSpeed, delay: 0.0, options: .curveEaseIn, animations: {
                self.animationView.frame = CGRect(x: 0, y: 0, width: self.animationViewDiameter, height: self.animationViewDiameter)
                self.animationView.center = self.relativeCenterPoint
                self.animationView.layer.cornerRadius = self.animationViewDiameter / 2.0
                self.animationView.clipsToBounds = true
            }, completion: nil)
        }
    }
    
    func cancelAnimation() {
        self.invalidateAnimationView()
    }
    
    func invalidateAnimationView() {
        self.layer.borderColor = self.statelessBorderColor?.cgColor
        self.animationView.frame = .zero
        self.animationView.center = self.relativeCenterPoint
        self.animationView.layer.cornerRadius = 0.0
    }
}
