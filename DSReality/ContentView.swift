//
//  ContentView.swift
//  DSReality
//
//  Created by Zhuowei Zhang on 2023-06-19.
//

import SwiftUI
import RealityKit
import MelonDSDeltaCore
import DeltaCore

struct ContentView : View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
              
        let arView = ARView(frame: .zero)
      
      Delta.register(MelonDS.core)
      let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let game = Game(fileURL: documentDirectory.appendingPathComponent("rom.bin"), type: .ds)
      let emulatorCore = EmulatorCore(game: game)
      emulatorCore?.start()
        
        // Load the "Box" scene from the "Experience" Reality File
        //let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        //arView.scene.anchors.append(boxAnchor)
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
