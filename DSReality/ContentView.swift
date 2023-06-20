//
//  ContentView.swift
//  DSReality
//
//  Created by Zhuowei Zhang on 2023-06-19.
//

import ARKit
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
  // https://github.com/rileytestut/Delta/blob/7f79e1d3a6bb1f1fa49d39099093c25f749e19ee/Delta/Emulation/GameViewController.swift#LL201C1-L202C1
  NotificationCenter.default.addObserver(
    forName: .externalGameControllerDidConnect, object: nil, queue: nil
  ) { notification in
    let controllers = ExternalGameControllerManager.shared.connectedControllers
    if controllers.count == 0 {
      return
    }
    controllers[0].removeReceiver(emulatorCore)
    controllers[0].addReceiver(emulatorCore)
  }
  ExternalGameControllerManager.shared.startMonitoring()
  emulatorCore.start()
  return emulatorCore
}

struct ContentView: View {
  var body: some View {
    HStack {
      GameViewContainer().frame(width: 256, height: 192 * 2)
      ARViewContainer().edgesIgnoringSafeArea(.all)
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
        let decodedTextures = decodeTexturesFrom(rip: melonRipperRip)
        // seriously?!
        DispatchQueue.main.async {
          let modelComponent = realityKitModelFromRip(
            rip: melonRipperRip, textures: decodedTextures)
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
