//
//  CaptureSession.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 07.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import Foundation
import AVFoundation

/// Protocol which notify about new texture.
protocol CaptureSessionDelegate: class {
    
    /// Triggered, when new texture did receive.
    ///
    /// - Parameters:
    ///   - _: Capture session.
    ///   - texture: Received texture.
    func captureSession(_ : CaptureSession, didReceiveTexture texture: MTLTexture)
}

/// Manipulates camera streaming.
class CaptureSession: NSObject {
    
    weak var delegate: CaptureSessionDelegate?
    let size: (width: Int, height: Int) = (width: 720, height: 1280)
    
    private var sessionQueue = DispatchQueue(label: "CaptureSessionQueue")
    private var textureCache: CVMetalTextureCache?
    private let captureSession = AVCaptureSession()
    private let captureDevice: CaptureDevice
    private let textureConverter = TextureConverter()

    init(metalDevice: MTLDevice, captureDevice: CaptureDevice)
    {
        self.captureDevice = captureDevice
        captureSession.sessionPreset = .iFrame1280x720
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache)
    }
    
    /// Start camera streaming.
    func start() {
        requestCaptureDeviceAccess()
        
        captureSession.beginConfiguration()
        configureDeviceInput()
        configureDeviceOutput()
        captureSession.commitConfiguration()
        
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    /// Stop camera streaming.
    func stop() {
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    
    private func requestCaptureDeviceAccess() {
        captureDevice.requestAccess { (succeeded) in
            guard succeeded else {
                print("Doesn't got access for video")
                return
            }
        }
    }
    
    private func configureDeviceInput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice.device)
            if (captureSession.canAddInput(captureDeviceInput)) {
                captureSession.addInput(captureDeviceInput)
            }
        } catch {
            print("Cannot get capture input")
        }
    }
    
    private func configureDeviceOutput() {
        let outputData = AVCaptureVideoDataOutput()
        outputData.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        outputData.setSampleBufferDelegate(self, queue: sessionQueue)
        
        guard captureSession.canAddOutput(outputData) else {
            print("Cannot add capture output")
            return
        }
        
        captureSession.addOutput(outputData)
        
        guard let videoConnection = outputData.connections.first else {
            print("Cannot set video orientation")
            return
        }
        
        videoConnection.videoOrientation = .portrait
    }
}


extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cache = textureCache else { return }
        
        guard let metalTexture = textureConverter.convert(sampleBuffer: sampleBuffer, with: cache) else { return }
        delegate?.captureSession(self, didReceiveTexture: metalTexture)
    }
}
