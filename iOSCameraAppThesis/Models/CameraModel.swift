//
//  CameraModel.swift
//  iOSCameraAppThesis
//
//  Created by David Mansourian on 2024-03-07.
//

import AVFoundation
import Foundation
import Photos

@Observable
final class CameraModel: NSObject, AVCapturePhotoCaptureDelegate {
    public var preview: AVCaptureVideoPreviewLayer!
        
    private var capturedPhotoData: Data?
    private var currentDevice: AVCaptureDevice?
    private var output = AVCapturePhotoOutput()
    private var position: AVCaptureDevice.Position = .back

    private(set) var isCameraAuthorized: Bool?
    private(set) var isTaken = false
    private(set) var useFlash = false
    private(set) var session = AVCaptureSession()
    
    
    override init() {
        super.init()
        Task { await setUp() }
    }
    
    private var bestDevice: AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera], mediaType: .video, position: position).devices.first
    }
    
    private var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            var isAuthorized = status == .authorized
            
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            
            self.isCameraAuthorized = isAuthorized
            return isAuthorized
        }
    }
    
    public var isPhotoLibraryReadWriteAccessGranted: Bool {
        get async {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            
            var isAuthorized = status == .authorized
            
            if status == .notDetermined {
                isAuthorized = await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
            }
            
            return isAuthorized
        }
    }
    
    private func setUp() async {
        guard await isAuthorized else { return }
        
        do {
            session.beginConfiguration()
            
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }
            
            guard let device = bestDevice else { return }
            currentDevice = device
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func checkFlashSettings(for device: AVCaptureDevice) -> AVCapturePhotoSettings {
        let photoSettings = AVCapturePhotoSettings()
        guard useFlash else { return photoSettings }
        
        switch position {
        case .unspecified:
            print("Position is unspecified.")
        case .back:
            do {
                try device.lockForConfiguration()
                device.torchMode = .on
                device.unlockForConfiguration()
            } catch {
                print("Error configuring flash: \(error)")
            }
        case .front:
            photoSettings.flashMode = .on
        @unknown default:
            print("Unknown case")
        }
        
        return photoSettings
    }
    
    private func photoUpdateUI() {
        isTaken.toggle()
    }
    
    public func toggleFlashMode() {
        useFlash.toggle()
    }
    
    public func capturePhoto() {
        self.photoUpdateUI()
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self, let device = currentDevice else { return }
            let photoSettings = checkFlashSettings(for: device)
            self.output.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    public func retakePhoto() {
        photoUpdateUI()
        capturedPhotoData = nil
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            self.session.startRunning()
        }
    }
    
    public func changeCameras() async {
        session.stopRunning()
        position = (position == .back ? .front : .back)
        await setUp()
        startCamera()
    }
    
    public func startCamera() {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            self.session.startRunning()
        }
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        
        session.stopRunning()
        
        print("photo taken")
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        capturedPhotoData = imageData
        
    }
    
    
    
    public func savePhotoCapture() async -> Result<String, Error> {
        guard await isPhotoLibraryReadWriteAccessGranted else { return .failure(SaveError.notAuhtorized) }
        
        if let photoData = capturedPhotoData {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: photoData, options: nil)
                }
                return .success("Photo was saved to camera roll")
            } catch {
                print("error saving photo to camera roll")
                return .failure(SaveError.failedSaving)
            }
        } else {
            return .failure(SaveError.corruptData)
        }
    }
}

extension CameraModel {
    enum SaveError: Error {
        case notAuhtorized, failedSaving, corruptData
        
        var customDescription: String {
            switch self {
            case .notAuhtorized:
                return "App is not authorized to save photos"
            case .failedSaving:
                return "Error saving photo"
            case .corruptData:
                return "Capture output was corrupted"
            }
        }
    }
}
