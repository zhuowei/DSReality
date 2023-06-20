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

var emulatorCore: EmulatorCore!

func getOrStartEmulator() -> EmulatorCore {
  if let emulatorCore = emulatorCore {
    return emulatorCore
  }
  Delta.register(MelonDS.core)
  let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  let game = Game(fileURL: documentDirectory.appendingPathComponent("mario_kart_ds.nds"), type: .ds)
  emulatorCore = EmulatorCore(game: game)
  emulatorCore.start()
  return emulatorCore
}

struct ContentView : View {
    var body: some View {
      ZStack {
        //ARViewContainer().edgesIgnoringSafeArea(.all)
        GameViewContainer()
      }
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
              
        let arView = ARView(frame: .zero)
        
        // Load the "Box" scene from the "Experience" Reality File
        //let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        //arView.scene.anchors.append(boxAnchor)
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

struct GameViewContainer: UIViewRepresentable {
  func makeUIView(context: Context) -> GameView {
    let gameView = GameView(frame: .zero)
    getOrStartEmulator().add(gameView)
    return gameView
  }
  func updateUIView(_ uiView: GameView, context: Context) {
  }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
