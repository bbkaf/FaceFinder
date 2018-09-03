//
//  DataCenter.swift
//  FaceLandmarkDetection
//
//  Created by HankTseng on 2018/9/2.
//  Copyright © 2018年 Devtechie. All rights reserved.
//

import UIKit

class DataCenter {
    static let shared = DataCenter()
    var cropedFaces: [FaceDetail] = []
    
}

struct FaceDetail {
    var cropedFaces: UIImage? = nil
    var name: String? = ""
}
