//
//  SavedFacesViewController.swift
//  FaceLandmarkDetection
//
//  Created by HankTseng on 2018/9/2.
//  Copyright © 2018年 Devtechie. All rights reserved.
//

import UIKit

class SavedFacesViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var collectionCellSpacing: CGFloat = 4.0
    
    @IBOutlet weak var faceCollectionView: UICollectionView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        // Do any additional setup after loading the view.
    }
    
    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = self.collectionCellSpacing
        layout.minimumInteritemSpacing = self.collectionCellSpacing
        faceCollectionView.collectionViewLayout = layout
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return DataCenter.shared.cropedFaces.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CropedFaceCollectionViewCell", for: indexPath) as! CropedFaceCollectionViewCell
        cell.faceImage.image = DataCenter.shared.cropedFaces[indexPath.row].cropedFaces
        cell.name.text = DataCenter.shared.cropedFaces[indexPath.row].name
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = ((faceCollectionView.bounds.width - (2 * self.collectionCellSpacing)) / 3)
        return CGSize(width: width, height: width )
    }

}
