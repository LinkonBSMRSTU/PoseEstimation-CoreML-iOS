//
//  VideoCapture.swift
//  PoseEstimation-CoreML
//
//  Created by Fazle Rabbi Linkon on 22/11/2020.
//  Copyright © 2020 Fazle Rabbi Linkon. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo

public protocol VideoCaptureDelegate: class {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer, timestamp: CMTime)
}

public class VideoCapture: NSObject {
    public var previewLayer: CALayer?
    public weak var delegate: VideoCaptureDelegate?
    public var fps = 30
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    var lastTimestamp = CMTime()
    
    public func setUp(sessionPreset: AVCaptureSession.Preset = .vga640x480,
                      cameraPosition: AVCaptureDevice.Position = .back,
                      completion: @escaping (Bool) -> Void) {
        sessionQueue.async {
            self.setUpCamera(sessionPreset: sessionPreset,
                             cameraPosition: cameraPosition,
                             completion: { success in
                completion(success)
            })
        }
    }
    
    func setUpCamera(sessionPreset: AVCaptureSession.Preset, cameraPosition: AVCaptureDevice.Position, completion: @escaping (_ success: Bool) -> Void) {
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            fatalError("Error: no video devices available")
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            fatalError("Error: could not create AVCaptureDeviceInput")
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // We want the buffers to be in portrait orientation otherwise they are
        // rotated by 90 degrees. Need to set this _after_ addOutput()!
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        
        let success = true
        completion(success)
    }
    
    public func start() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    public func stop() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Because lowering the capture device's FPS looks ugly in the preview,
        // we capture at full speed but only call the delegate at its desired
        // framerate.
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            lastTimestamp = timestamp
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("dropped frame")
    }
}

