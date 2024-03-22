//
//  ContentView.swift
//  iOSCameraAppThesis
//
//  Created by David Mansourian on 2024-03-07.
//

import SwiftUI

struct CameraView: View {
    @State private var camera = Camera()
    @State private var bannerText: String?
    @State private var isSaving = false
    @State private var isSaveSuccess = false
    
    var body: some View {
        Group {
            switch camera.state {
            case .authorized:
                ZStack {
                    Color.black
                        .ignoresSafeArea(.all)
                    
                    CameraPreview(camera: camera)
                        .ignoresSafeArea(.all)
                        .cornerRadius(20)
                        .onTapGesture(count: 2, perform: switchCamera)
                    
                    VStack {
                        if let notice = bannerText {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(isSaveSuccess ? .green : .red)
                                .frame(
                                    width: UIScreen.main.bounds.width * 0.7,
                                    height: UIScreen.main.bounds.height * 0.065
                                )
                                .padding()
                                .overlay {
                                    Text(notice)
                                        .foregroundStyle(.white)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                        }
                        
                        VStack {
                            if camera.isTaken, !isSaving {
                                discardPhotoButton
                            } else if !camera.isTaken, !isSaving {
                                toggleFlashButton
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: camera.isTaken ? .leading : .trailing)
                        
                        Spacer()
                        
                        HStack {
                            if camera.isTaken, !isSaving {
                                Spacer()
                                saveToCameraRollButton
                            } else if !camera.isTaken {
                                capturePhotoButton
                            }
                        }
                        .padding()
                    }
                }
            case .unknown, .notAuthorized, .noDeviceFound:
                ContentUnavailableView("Couldn't use Camera",
                                       systemImage: "gear",
                                       description: Text(camera.state.description))
            }
        }
    }
}

extension CameraView {
    private var discardPhotoButton: some View {
        Button(action: camera.retakePhoto) {
            Text("X")
                .foregroundStyle(.white)
                .font(.title)
                .fontWeight(.semibold)
        }
        .buttonStyle(.plain)
    }
    
    private var toggleFlashButton: some View {
        Button(action: camera.toggleFlashMode) {
            Image(systemName: camera.useFlash ? "bolt.fill" : "bolt.slash.fill")
                .foregroundStyle(.white)
                .font(.title)
                .fontWeight(.semibold)
        }
        .padding(.trailing, 5)
    }
    
    private var capturePhotoButton: some View {
        Button(action: camera.capturePhoto) {
            Circle()
                .strokeBorder(Color.white, lineWidth: 6)
                .frame(width: 80, height: 80)
        }
    }
    
    private var saveToCameraRollButton: some View {
        Button(action: save) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 30))
                .padding(10)
                .foregroundStyle(.black)
                .background(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.leading)
    }
    
    private func switchCamera() {
        if !camera.isTaken {
            Task {
                await camera.changeCameras()
            }
        }
    }
    
    private func save() {
        Task {
            isSaving = true
            do {
                try await camera.savePhotoCapture()
                isSaveSuccess = true
                camera.retakePhoto()
                await show(bannerText: "Photo was saved to camera roll")
            } catch {
                isSaveSuccess = false
                await show(bannerText: error.localizedDescription)
            }
            isSaving = false
        }
    }
    
    private func show(bannerText: String, duration: Int = 2) async {
        withAnimation {
            self.bannerText = bannerText
        }
        
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        withAnimation {
            self.bannerText = nil
        }
    }
}

#Preview {
    CameraView()
}
