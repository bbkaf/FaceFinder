//
//  ViewController.swift
//  FaceLandmarkDetection
//
//  Created by Anoop tomar on 3/30/18.
//  Copyright © 2018 Devtechie. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: PreviewView!
    
    var devicePosition:AVCaptureDevice.Position = .front
    
    @IBOutlet weak var faceCounts: UILabel! {
        didSet {
            faceCounts.layer.cornerRadius = 4.0
        }
    }
    
    
    var session = AVCaptureSession()
    var isSessionRunning = false
    let sessionQueue = DispatchQueue(label: "AV Session Queue")
    var sessionSetupResult: SessionSetupResult = .success
    var videoDeviceInput: AVCaptureInput!
    var videoDeviceOutput: AVCaptureVideoDataOutput!
    var videoDataOutputQueue = DispatchQueue(label: "Video data output queue")
    
    var requests = [VNRequest]()
    var faceCiimage: CIImage? = nil
    var testUIImage: UIImage? = nil
    var faceDetectionRequest: VNRequest!
    var cropedFaces: [UIImage] = []
    
    var dstWidth: CGFloat = 227
    var dstHeight: CGFloat = 227
    var isSleep = false
    var sleepTime = 1.0
    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.session = session
        faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleFaceLandmarks)
        
        self.seupVision()
        self.setCameraAuth()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.sessionSetupResult {
            case .success:
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let message = "Please allow camera access to do face detection"
                    let alertController = UIAlertController(title: "Face Detection", message: message, preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: "Open Settings", style: UIAlertActionStyle.default, handler: { (action) in
                        UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            case .configurationFailed:
                let message = "Unable to capture due to configuration issues"
                let alertController = UIAlertController(title: "Face Detection", message: message, preferredStyle: UIAlertControllerStyle.alert)
                alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
                
                self.present(alertController, animated: true, completion: nil)
            }
            
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.sessionSetupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if let videoPreviewConnection = previewView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = deviceOrientation.videoOrientation,
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }
            
            videoPreviewConnection.videoOrientation = newVideoOrientation
            
        }
    }
    
    func setCameraAuth() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { (granted) in
                if !granted {
                    self.sessionSetupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }
        default:sessionSetupResult = .notAuthorized
        }
        
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    func configureSession() {
        if self.sessionSetupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let dualCamraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInDualCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.front) {
                defaultVideoDevice = dualCamraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.front) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCamera = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.front) {
                defaultVideoDevice = frontCamera
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                DispatchQueue.main.async {
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    self.previewView.videoPreviewLayer.connection!.videoOrientation = initialVideoOrientation
                }
            }
            else {
                print("Can't add video device input to session")
                sessionSetupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print(error)
            sessionSetupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        videoDeviceOutput = AVCaptureVideoDataOutput()
        videoDeviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        if session.canAddOutput(videoDeviceOutput) {
            videoDeviceOutput.alwaysDiscardsLateVideoFrames = true
            videoDeviceOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            session.addOutput(videoDeviceOutput)
        } else {
            print("Can't add output to session")
            sessionSetupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    func exifOrientaionFromDeviceOrientation() -> UInt32 {
        enum DeviceOrientation: UInt32 {
            case topLeft = 1
            case topRight = 2
            case bottomRight = 3
            case bottomLeft = 4
            case leftTop = 5
            case rightTop = 6
            case rightBottom = 7
            case leftBottom = 8
        }
        
        var exifOrientation : DeviceOrientation
        
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .leftBottom
        case .landscapeLeft:
            exifOrientation = devicePosition == .front ? .bottomRight : .topLeft
        case .landscapeRight:
            exifOrientation = devicePosition == .front ? .topLeft : .bottomRight
        default:
            exifOrientation = .rightTop
        }
        
        return exifOrientation.rawValue
    }
}

extension ViewController {
    func handleFaces(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results as? [VNFaceObservation] else {return}
            self.previewView.removeMask()
            for face in results {
                self.previewView.drawFaceBoundingBox(faceObservation: face)
                
            }
        }
    }
    
    func handleFaceLandmarks(request: VNRequest, error: Error?) {
        
        
        DispatchQueue.main.async {
            guard let results = request.results as? [VNFaceObservation] else {return}
            self.previewView.removeMask()
            for face in results {
                self.previewView.drawFaceWithLandmarks(faceObservation: face)
                
                
                if self.testUIImage != nil {
                    
                    let imageWidth = self.testUIImage!.size.width
                    let imageHeight = self.testUIImage!.size.height
                    let boxWidth = face.boundingBox.width * imageWidth
                    let boxHeight = face.boundingBox.height * imageHeight
                    let boxOriginX = face.boundingBox.origin.x * imageWidth
                    let boxOriginY = (1 - face.boundingBox.origin.y) * imageHeight - boxHeight
                    let faceRect = CGRect(x: boxOriginX, y: boxOriginY, width: boxWidth, height: boxHeight)
                    
                    if let ciImage = Utility.shared.convertUIImageToCIImage(uiImage: self.testUIImage!) {
                        if let cropedFaceImage = self.corpFaceCIImage(with: ciImage, bounds: faceRect)?.resize(newWidth: self.dstWidth) {
                            print(cropedFaceImage.size)
                            DataCenter.shared.cropedFaces.append(FaceDetail(cropedFaces: cropedFaceImage, name: "\(DataCenter.shared.cropedFaces.count)"))
                            UIImageWriteToSavedPhotosAlbum(cropedFaceImage, nil, nil, nil)
                            self.faceCounts.text = "\(DataCenter.shared.cropedFaces.count)"
                            print("fetch \(DataCenter.shared.cropedFaces.count) faces")
                        }
                    }
                }
            }
        }
        
        
    }
    
    
    
    func seupVision() {
        self.requests = [faceDetectionRequest]
    }
    
    func corpFaceCIImage(with ciimage: CIImage?, bounds: CGRect) -> UIImage? {
        if ciimage != nil {
            let cgImage = Utility.shared.convertCIImageToCGImage(ciImage: ciimage!)
                let cropedCGImage = cgImage.cropping(to: bounds)
                if cropedCGImage != nil {
                    let uiimage = UIImage(cgImage: cropedCGImage!)
//                    print(uiimage.size)
                    return uiimage
                } else {
                    return nil
                }
        }
        return nil
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let exifOrientation = CGImagePropertyOrientation(rawValue: self.exifOrientaionFromDeviceOrientation()) else {return}
        self.faceCiimage = convert(buffer: pixelBuffer)
        var requestOptions: [VNImageOption: Any] = [:]
        
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [VNImageOption.cameraIntrinsics: cameraIntrinsicData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
        self.testUIImage = getImageFromSampleBuffer(buffer: sampleBuffer)
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
    
    private func convert(buffer: CVImageBuffer) -> CIImage? {
        let ciImage: CIImage = CIImage(cvPixelBuffer: buffer)
        return ciImage.orientationCorrectedImage()
    }
    
    func getImageFromSampleBuffer (buffer:CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            let srcWidth = CGFloat(ciImage.extent.width)
            let srcHeight = CGFloat(ciImage.extent.height)
            
            
            
            let scaleX = dstWidth / srcWidth
            let scaleY = dstHeight / srcHeight
            let scale = min(scaleX, scaleY)
            
            let transform = CGAffineTransform.init(scaleX: 1, y: 1)
            let rotationTransForm = CGAffineTransform(rotationAngle: CGFloat(-M_PI*0.5));
//            let output = ciImage.transformed(by: rotationTransForm).cropped(to: CGRect(x: 0, y: 0, width: srcWidth, height: srcHeight))
            let output = ciImage.transformed(by: rotationTransForm)
//            let rotationCIImage = output.transformed(by: rotationTransForm)
            
            return UIImage(ciImage: output)
        }
        
        return nil
    }

}

extension ViewController {
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension CIImage {
    func orientationCorrectedImage() -> CIImage? {
        var imageOrientation = UIImageOrientation.up
        DispatchQueue.main.async {
            switch UIApplication.shared.statusBarOrientation {
            case UIInterfaceOrientation.portrait:
                imageOrientation = UIImageOrientation.right
            case UIInterfaceOrientation.landscapeLeft:
                imageOrientation = UIImageOrientation.down
            case UIInterfaceOrientation.landscapeRight:
                imageOrientation = UIImageOrientation.up
            case UIInterfaceOrientation.portraitUpsideDown:
                imageOrientation = UIImageOrientation.left
            default:
                break;
            }
        }
        
        var w = self.extent.size.width
        var h = self.extent.size.height
        
        if imageOrientation == .left || imageOrientation == .right || imageOrientation == .leftMirrored || imageOrientation == .rightMirrored {
            swap(&w, &h)
        }
        
        UIGraphicsBeginImageContext(CGSize(width: w, height: h));
        
        UIImage.init(ciImage: self, scale: 1.0, orientation: imageOrientation).draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        let uiImage:UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();
        if uiImage != nil {
            return CIImage.init(image: uiImage!)
        } else {
            return nil
        }
    }
}

































