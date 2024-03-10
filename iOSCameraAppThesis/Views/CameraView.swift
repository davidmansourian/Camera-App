//
//  ContentView.swift
//  iOSCameraAppThesis
//
//  Created by David Mansourian on 2024-03-07.
//

import SwiftUI

struct CameraView: View {
    @State private var camera = CameraModel()
    @State private var bannerText: String?
    @State private var isSaving = false
    @State private var isSaveSuccess = false
    
    var body: some View {
        Group {
            if let isAuthorized = camera.isCameraAuthorized, isAuthorized {
                ZStack {
                    Color.black
                        .ignoresSafeArea(.all)
                    
                    CameraPreview(camera: camera)
                        .ignoresSafeArea(.all)
                        .cornerRadius(20)
                        .onTapGesture(count: 2) {
                            switchCamera()
                        }
                    
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
            } else {
                ContentUnavailableView("Couldn't use Camera",
                                       systemImage: "gear",
                                       description: Text("To use the camera, please enable camera access in your phone's Settings."))
            }
        }
    }
}

extension CameraView {
    private var discardPhotoButton: some View {
        Button(action: {
            camera.retakePhoto()
        }, label: {
            Text("X")
                .foregroundStyle(.white)
                .font(.title)
                .fontWeight(.semibold)
        })
        .buttonStyle(.plain)
    }
    
    private var toggleFlashButton: some View {
        Button(action: {camera.toggleFlashMode()}, label: {
            Image(systemName: camera.useFlash ? "bolt.fill" : "bolt.slash.fill")
                .foregroundStyle(.white)
                .font(.title)
                .fontWeight(.semibold)
        })
        .padding(.trailing, 5)
    }
    
    private var capturePhotoButton: some View {
        Button(action: {camera.capturePhoto()}, label: {
            Circle()
                .strokeBorder(Color.white, lineWidth: 6)
                .frame(width: 80, height: 80)
        })
    }
    
    private var saveToCameraRollButton: some View {
        Button(action: {
            Task { await handleSave() }
        }, label: {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 30))
                .padding(10)
                .foregroundStyle(.black)
                .background(.white)
                .clipShape(Circle())
        })
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
    
    private func handleSave() async {
        let result = await camera.savePhotoCapture()
        isSaveSuccess = result.isSuccess
        
        switch result {
        case .success(let successMessage):
            camera.retakePhoto()
            toggleBanner(successMessage)
        case .failure(let error):
            if let saveError = error as? CameraModel.SaveError {
                toggleBanner(saveError.customDescription)
            }
        }
    }
    
    private func toggleBanner(_ bannerText: String) {
        Task {
            withAnimation {
                isSaving.toggle()
                self.bannerText = bannerText
            }
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            withAnimation {
                self.bannerText = nil
                isSaving.toggle()
            }
        }
    }
}

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

#Preview {
    CameraView()
}
