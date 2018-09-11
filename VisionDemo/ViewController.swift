 //
//  ViewController.swift
//  VisionDemo
//
//  Created by Yudiz Solutions on 31/08/18.
//  Copyright © 2018 Yudiz Solutions. All rights reserved.
//

 import UIKit
 import Vision
 import ImageIO
 import Accelerate
 import Photos
 
class ViewController: UIViewController {

    ///Outlets
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var faceImgView: UIImageView!
    
    /// Variables
    var imagePicker: UIImagePickerController!
    var image: UIImage!
    var pathLayer: CALayer?
    var imageWidth: CGFloat = 0
    var imageHeight: CGFloat = 0
    
    /// ConfigureCompletionHandler
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleFaceDetection)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("View Did Load Method")
    }
    
    /// Creating vision requests
    func createVisionRequests() -> [VNRequest] {
        var requests: [VNRequest] = []
        requests.append(self.faceDetectionRequest)
        return requests
    }
    
    /// Performing all vision requests
    func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
        let requests = createVisionRequests()
        let imageRequestHandler = VNImageRequestHandler(cgImage: image,
                                                        orientation: orientation,
                                                        options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try imageRequestHandler.perform(requests)
            } catch let error as NSError {
                print("Failed to perform image request: \(error)")
                return
            }
        }
    }
}

// MARK: - Actions
extension ViewController {
    
    @IBAction func btnChooseImageAction(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let camera = UIAlertAction(title: "Camera", style: .default, handler: { (action) in
            self.openCamera()
        })
        let library = UIAlertAction(title: "Photo Library", style: .default, handler: { (action) in
            self.openLibrary()
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(camera)
        alert.addAction(library)
        alert.addAction(cancel)
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - Vision related methods
extension ViewController {
    
    /// Cropping face to display on another ImageView
    func cropFaceImage(face: VNFaceObservation) {
        let imgSize = self.image.size
        let obsRect = face.boundingBox
        let newRect = CGRect(x: obsRect.minX * imgSize.width, y: ((1 - obsRect.minY) * imgSize.height) - (obsRect.height * imgSize.height), width: obsRect.width * imgSize.width, height: obsRect.height * imgSize.height)
        
        if self.image != nil {
            guard let cgImage = self.image.cgImage else {
                print("CG error")
                return
            }
            let croppedImage = cgImage.cropping(to: newRect)
            let faceImg = UIImage(cgImage: croppedImage!)
            self.faceImgView.image = faceImg
        }
    }
    
    func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        return rect
    }
    
    func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
        // Create a new layer.
        let layer = CAShapeLayer()
        
        // Configure layer's appearance.
        layer.fillColor = nil
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 2
        
        // Vary the line color according to input.
        layer.borderColor = color.cgColor
        
        // Locate the layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        layer.transform = CATransform3DMakeScale(1, -1, 1)
        return layer
    }
    
    func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        if faces.count > 0 {
            for observation in faces {
                let faceBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
                let faceLayer = shapeLayer(color: .yellow, frame: faceBox)
                pathLayer?.addSublayer(faceLayer)
                self.cropFaceImage(face: observation)
            }
        } else {
            let alert = UIAlertController(title: "No Face Found", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        CATransaction.commit()
    }
    
    func handleFaceDetection(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            print(nsError.localizedDescription)
            return
        }
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer,
                let results = request?.results as? [VNFaceObservation] else {
                    return
            }
            self.draw(faces: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
}

 // MARK: - ImagePicker & Navigation delegate methods
 extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func openCamera(){
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func openLibrary(){
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {
            imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    /// UIImagePickerController Delegate methods
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let originalImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        self.faceImgView.image = nil
        self.image = originalImage
        self.show(self.image)
        picker.dismiss(animated: true, completion: nil)
    }
    
    func show(_ image: UIImage) {
        
        // Remove previous paths & image
        pathLayer?.removeFromSuperlayer()
        pathLayer = nil
        imgView.image = nil
        self.image = self.image.fixedOrientation().scaleAndManageAspectRatio(500) // Fixed orientation and scale
        self.imgView.image = self.image
        
        guard let chImg = self.image.cgImage else {
            print("No CGImage found")
            return
        }
        // Performing vision requests
        performVisionRequest(image: chImg, orientation: CGImagePropertyOrientation.init(self.image))
        
        let fullImageWidth = CGFloat(chImg.width)
        let fullImageHeight = CGFloat(chImg.height)
        
        let imageFrame = imgView.frame
        let widthRatio = fullImageWidth / imageFrame.width
        let heightRatio = fullImageHeight / imageFrame.height
        
        // ScaleAspectFit: The image will be scaled down according to the stricter dimension.
        let scaleDownRatio = max(widthRatio, heightRatio)
        
        // Cache image dimensions to reference when drawing CALayer paths.
        imageWidth = fullImageWidth / scaleDownRatio
        imageHeight = fullImageHeight / scaleDownRatio
        
        // Prepare pathLayer to hold Vision results.
        let xLayer = (imageFrame.width - imageWidth) / 2
        let yLayer = imgView.frame.minY + (imageFrame.height - imageHeight) / 2
        let drawingLayer = CALayer()
        drawingLayer.bounds = CGRect(x: xLayer, y: yLayer, width: imageWidth, height: imageHeight)
        drawingLayer.anchorPoint = CGPoint.zero
        drawingLayer.position = CGPoint(x: xLayer, y: yLayer)
        drawingLayer.opacity = 0.5
        pathLayer = drawingLayer
        self.view.layer.addSublayer(pathLayer!)
    }
 }
 
 /// to give cgImage orientation as UIImage
 extension CGImagePropertyOrientation {
    
    init(_ uiimage: UIImage) {
        switch uiimage.imageOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        }
    }
 }

 /// to give fix orientation and scale to image
 extension UIImage {
    
    /// This method will scale selected image according to its orientation
    func scaleAndManageAspectRatio(_ width: CGFloat) -> UIImage {
        if let cgImage = cgImage {
            let oldWidth = size.width
            let oldHeight = size.height
            if oldHeight < width && oldWidth < width {
                return self
            }
            let scaleFactor = oldWidth > oldHeight ? width/oldWidth : width/oldHeight
            let newHeight = oldHeight * scaleFactor
            let newWidth = oldWidth * scaleFactor;
            var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),version: 0, decode: nil, renderingIntent: CGColorRenderingIntent.defaultIntent)
            var sourceBuffer = vImage_Buffer()
            defer {
                sourceBuffer.data.deallocate()
            }
            var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, numericCast(kvImageNoFlags))
            guard error == kvImageNoError else { return self }
            
            // create a destination buffer
            let scale = self.scale
            let destWidth = Int(newWidth)
            let destHeight = Int(newHeight)
            let bytesPerPixel = cgImage.bitsPerPixel/8
            let destBytesPerRow = destWidth * bytesPerPixel
            let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: destHeight * destBytesPerRow)
            defer {
                destData.deallocate()
            }
            var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(destHeight), width: vImagePixelCount(destWidth), rowBytes: destBytesPerRow)
            
            // scale the image
            error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, numericCast(kvImageHighQualityResampling))
            guard error == kvImageNoError else { return self }
            
            // create a CGImage from vImage_Buffer
            let destCGImage = vImageCreateCGImageFromBuffer(&destBuffer, &format, nil, nil, numericCast(kvImageNoFlags), &error)?.takeRetainedValue()
            guard error == kvImageNoError else { return self }
            
            // create a UIImage
            let imgOutPut = destCGImage.flatMap { (cgImage) -> UIImage? in
                return UIImage(cgImage: cgImage, scale: 0.0, orientation: imageOrientation)
            }
            return imgOutPut ?? self
        }else{
            return self
        }
    }
    
    /// this method will fix the orientation of selected image
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
            break
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
            break
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
            break
        case .up, .upMirrored:
            break
        }
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform.translatedBy(x: size.width, y: 0)
            transform.scaledBy(x: -1, y: 1)
            break
        case .leftMirrored, .rightMirrored:
            transform.translatedBy(x: size.height, y: 0)
            transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        }
        
        let ctx: CGContext = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0, space: self.cgImage!.colorSpace!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        return UIImage(cgImage: ctx.makeImage()!)
    }
 }
