//
//  ContentView.swift
//  DSReality
//
//  Created by Zhuowei Zhang on 2023-06-19.
//

import DeltaCore
import MelonDSDeltaCore
import RealityKit
import SwiftUI

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

struct ContentView: View {
  var body: some View {
    ZStack(alignment: .topLeading) {
      ARViewContainer().edgesIgnoringSafeArea(.all)
      GameViewContainer().frame(width: 256, height: 192 * 2)
    }
  }
}

var g_busy: Bool = false

struct ARViewContainer: UIViewRepresentable {

  func makeUIView(context: Context) -> ARView {

    let arView = ARView(frame: .zero)

    // Load the "Box" scene from the "Experience" Reality File
    //let boxAnchor = try! Experience.loadBox()

    // Add the box anchor to the scene
    //arView.scene.anchors.append(boxAnchor)

    let newAnchor = AnchorEntity(world: [0, 0, -1])
    let newBox = ModelEntity()
    newBox.transform.scale = SIMD3<Float>(repeating: 0.5)
    // newBox.transform.rotation = simd_quatf(angle: Float.pi, axis: SIMD3<Float>(0, 1, 0))
    newAnchor.addChild(newBox)
    arView.scene.anchors.append(newAnchor)

    MelonDSEmulatorBridge.shared.melonRipperRipCallbackFunction = { inputData in
      if g_busy {
        return
      }
      g_busy = true
      DispatchQueue.global(qos: .userInteractive).async {
        let melonRipperRip = melonRipperRipFromDumpData(dump: inputData)
        if melonRipperRip.verts.count == 0 {
          g_busy = false
          return
        }
        // seriously?!
        DispatchQueue.main.async {
          let modelComponent = realityKitModelFromRip(rip: melonRipperRip)
          newBox.model = modelComponent
          g_busy = false
        }
      }
    }

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
  struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
      ContentView()
    }
  }
#endif
