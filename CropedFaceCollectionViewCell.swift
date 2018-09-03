//
//  CropedFaceCollectionViewCell.swift
//  FaceLandmarkDetection
//
//  Created by HankTseng on 2018/9/2.
//  Copyright © 2018年 Devtechie. All rights reserved.
//

import UIKit

class CropedFaceCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var faceImage: UIImageView! {
        didSet {
            faceImage.layer.cornerRadius = 20.0
        }
    }
    
    @IBOutlet weak var name: UILabel! {
        didSet {
            name.layer.cornerRadius = 20.0
        }
    }
    
}
