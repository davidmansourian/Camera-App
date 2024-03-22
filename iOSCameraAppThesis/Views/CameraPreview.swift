//
//  CameraPreview.swift
//  iOSCameraAppThesis
//
//  Created by David Mansourian on 2024-03-07.
//

import AVFoundation
import Foundation
import SwiftUI


struct CameraPreview: UIViewRepresentable {
    let camera: Camera
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        
        // Using detached task to perform action on background thread to avoid purple warning (Detached tasks do not follow parent and are not cancelled if parent is)
        Task.detached(priority: .userInitiated) {
            camera.session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}
