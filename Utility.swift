//
//  Utility.swift
//  FaceLandmarkDetection
//
//  Created by HankTseng on 2018/9/2.
//  Copyright © 2018年 Devtechie. All rights reserved.
//

import UIKit

class Utility {
    static let shared = Utility()
    
    func convertUIImageToCIImage(uiImage: UIImage) -> CIImage? {
        if let ciImage = uiImage.ciImage {
            return ciImage
        }
        if let cgImage = uiImage.cgImage {
            let ciImage = CIImage(cgImage: cgImage)
            return ciImage
        }
        return nil
    }
    
    func convertCIImageToCGImage(ciImage: CIImage) -> CGImage{
        let ciContext = CIContext.init()
        let cgImage:CGImage = ciContext.createCGImage(ciImage, from: ciImage.extent)!
        return cgImage
    }
    
}

extension UIImage {
    struct RotationOptions: OptionSet {
        let rawValue: Int
        
        static let flipOnVerticalAxis = RotationOptions(rawValue: 1)
        static let flipOnHorizontalAxis = RotationOptions(rawValue: 2)
    }
    
    func resize(newWidth: CGFloat) -> UIImage? {
        
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newWidth))
        self.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newWidth))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func rotated(by rotationAngle: Measurement<UnitAngle>, options: RotationOptions = []) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let rotationInRadians = CGFloat(rotationAngle.converted(to: .radians).value)
        let transform = CGAffineTransform(rotationAngle: rotationInRadians)
        var rect = CGRect(origin: .zero, size: self.size).applying(transform)
        rect.origin = .zero
        
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { renderContext in
            renderContext.cgContext.translateBy(x: rect.midX, y: rect.midY)
            renderContext.cgContext.rotate(by: rotationInRadians)
            
            let x = options.contains(.flipOnVerticalAxis) ? -1.0 : 1.0
            let y = options.contains(.flipOnHorizontalAxis) ? 1.0 : -1.0
            renderContext.cgContext.scaleBy(x: CGFloat(x), y: CGFloat(y))
            
            let drawRect = CGRect(origin: CGPoint(x: -self.size.width/2, y: -self.size.height/2), size: self.size)
            renderContext.cgContext.draw(cgImage, in: drawRect)
        }
    }
}
