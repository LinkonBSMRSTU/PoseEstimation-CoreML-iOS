//
//  HeatmapsViewController.swift
//  PoseEstimation-CoreML
//
//  Created by Fazle Rabbi Linkon on 22/11/2020.
//  Copyright © 2020 Fazle Rabbi Linkon. All rights reserved.
//

import UIKit
import Vision
import CoreMedia

class HeatmapsViewController: UIViewController {
    
    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var mainHeatmapView: DrawingHeatmapView!
    @IBOutlet var subHeatmapViews: [DrawingHeatmapView]!
    
    @IBOutlet weak var inferenceLabel: UILabel!
    @IBOutlet weak var etimeLabel: UILabel!
    @IBOutlet weak var fpsLabel: UILabel!
    
    // MARK: - Performance Measurement Property
    private let 👨‍🔧 = 📏()
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    // MARK: - ML Properties
    // Core ML model
    typealias EstimationModel = model_cpm
    
    // Preprocess and Inference
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // Postprocess
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup the model
        setUpModel()
        
        // setup camera
        setUpCamera()
        
        // setup delegate for performance measurement
        👨‍🔧.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError()
        }
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    DispatchQueue.main.async {
                        // your code here
                        self.videoPreview.layer.addSublayer(previewLayer)
                        self.resizePreviewLayer()
                    }
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    // MARK: - Poseprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        self.👨‍🔧.🏷(with: "endInference")
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {

            // convert heatmap to Array<Array<Double>>
            let heatmap = postProcessor.convertTo2DArray(from: heatmaps)
            let keypointCount = heatmaps.shape[0].intValue
            
            DispatchQueue.main.sync {
                
                //
                self.mainHeatmapView.heatmap3D = heatmap
                
                for (keypointNumber, subHeatmapView) in zip(0..<keypointCount, self.subHeatmapViews) {
                    subHeatmapView.heatmap3D = nil
                    subHeatmapView.keypointNumber = keypointNumber
                    subHeatmapView.heatmaps = heatmaps
                }
                
                // end of measure
                self.👨‍🔧.🎬🤚()
            }
        }
    }
}

// MARK: - VideoCaptureDelegate
extension HeatmapsViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        
        // start of measure
        self.👨‍🔧.🎬👏()
        
        // predict!
        self.predictUsingVision(pixelBuffer: pixelBuffer)
    }
}


// MARK: - 📏(Performance Measurement) Delegate
extension HeatmapsViewController: 📏Delegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        //print(executionTime, fps)
        self.inferenceLabel.text = "inference: \(Int(inferenceTime*1000.0)) mm"
        self.etimeLabel.text = "execution: \(Int(executionTime*1000.0)) mm"
        self.fpsLabel.text = "fps: \(fps)"
    }
}
