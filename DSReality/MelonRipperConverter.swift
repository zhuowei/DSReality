import CoreGraphics
import Foundation
import RealityKit

struct Vector3i {
  let x, y, z: Int32
}

struct Vector4ui {
  let a, b, c, d: Int32
  func toArray() -> [Int] {
    return [Int(a), Int(b), Int(c), Int(d)]
  }
}

struct MelonRipperRip {
  let verts: [SIMD3<Float>]
  let uvs: [SIMD2<Float>]
  let facesTriangle: [UInt32]
  let facesQuad: [UInt32]
  let faceMaterialsTriangle: [UInt32]
  let faceMaterialsQuad: [UInt32]
  let materials: [MelonRipperMaterialArgsKey: Int]
  let vramTex: Data
  let vramPal: [UInt16]
}

struct MelonRipperMaterialArgsKey: Hashable {
  let texparam: Int
  let texpal: Int
  let polygonAttr: Int
}

// Line-by-line port of https://github.com/scurest/MelonRipper/blob/master/import_melon_rip.py to Swift
func melonRipperRipFromDumpData(dump: Data) -> MelonRipperRip {
  var pos = 24  // end of magic
  var verts: [SIMD3<Float>] = []
  // r, g, b, useToonHighlight
  var colors: [UInt8] = []
  var uvs: [SIMD2<Float>] = []
  var facesTriangle: [UInt32] = []
  var facesQuad: [UInt32] = []
  var faceMaterialsTriangle: [UInt32] = []
  var faceMaterialsQuad: [UInt32] = []
  var materials: [MelonRipperMaterialArgsKey: Int] = [:]

  var texparam = 0
  var texpal = 0
  var polygonAttr = 0
  var blendMode = 0
  var textureWidth = 0
  var textureHeight = 0
  // TODO(zhuowei)
  var vramTex = Data()
  var vramPal = [UInt16]()
  while pos < dump.count {
    let op = dump[pos..<pos + 4].toString()
    pos += 4
    switch op {
    case "TRI ", "QUAD":
      let nverts = op == "TRI " ? 3 : 4
      if (polygonAttr >> 4) & 3 == 3 {
        // Skip shadow volumes; no idea what to do with these
        pos += (4 * 3 + 4 * 3 + 2 * 2) * nverts
        continue
      }
      let vertIndex = verts.count
      for i in 0..<nverts {
        let vert = dump.getGeneric(type: Vector3i.self, offset: UInt(pos))
        pos += 4 * 3
        let convertToFixedPointFactor = pow(Double(2), -12)
        verts.append(
          SIMD3<Float>(
            Float(Double(vert.x) * convertToFixedPointFactor),
            Float(Double(vert.y) * convertToFixedPointFactor),
            Float(Double(vert.z) * convertToFixedPointFactor)))
        let c = dump.getGeneric(type: Vector3i.self, offset: UInt(pos))
        pos += 4 * 3
        // Get back to 0-31 range (undo melonDS transform)
        let r = (c.x - 0xFFF) >> 12
        let g = (c.y - 0xFFF) >> 12
        let b = (c.z - 0xFFF) >> 12
        colors += [UInt8(r), UInt8(g), UInt8(b)]
        // The final vertex color is affected by whether
        // toon/highlight mode is enabled in disp_cnt, but
        // that doesn't come until the end of the file. So
        // for now just remember this so we can compute the
        // final color at the end.
        let useToonHighlight = (blendMode == 2)
        colors.append(useToonHighlight ? 1 : 0)
        let s = dump.getGeneric(type: UInt16.self, offset: UInt(pos))
        let t = dump.getGeneric(type: UInt16.self, offset: UInt(pos))
        pos += 2 * 2
        // Textures are upside down in Blender, so we flip them,
        // but that means we need to flip the T coord too.
        // zhuowei: RealityKit doesn't need to flip UVs
        uvs.append(
          SIMD2<Float>(Float(s) / 16 / Float(textureWidth), Float(t) / 16 / Float(textureHeight)))
        if nverts == 4 {
          facesQuad.append(UInt32(vertIndex + i))
        } else {
          facesTriangle.append(UInt32(vertIndex + i))
        }
      }
      let materialArgs = MelonRipperMaterialArgsKey(
        texparam: texparam, texpal: texpal, polygonAttr: polygonAttr)
      if materials[materialArgs] == nil {
        materials[materialArgs] = materials.count
      }
      let materialIndex = materials[materialArgs]!
      if nverts == 4 {
        faceMaterialsQuad.append(UInt32(materialIndex))
      } else {
        faceMaterialsTriangle.append(UInt32(materialIndex))
      }
    case "TPRM":
      texparam = Int(dump.getGeneric(type: Int32.self, offset: UInt(pos)))
      pos += 4
      textureWidth = 8 << ((texparam >> 20) & 7)
      textureHeight = 8 << ((texparam >> 23) & 7)
    case "TPLT":
      texpal = Int(dump.getGeneric(type: Int32.self, offset: UInt(pos)))
      pos += 4
    case "PATR":
      polygonAttr = Int(dump.getGeneric(type: Int32.self, offset: UInt(pos)))
      pos += 4
    case "VRAM":
      let vramMapTexture = dump.getGeneric(type: Vector4ui.self, offset: UInt(pos)).toArray()
      pos += 4 * 4
      let vramMapTexpal =
        dump.getGeneric(type: Vector4ui.self, offset: UInt(pos)).toArray()
        + dump.getGeneric(type: Vector4ui.self, offset: UInt(pos)).toArray()
      pos += 4 * 8
      var banks = [Data]()
      for _ in 0..<4 {
        banks.append(dump[pos..<pos + (128 << 10)])
        pos += 128 << 10
      }
      for _ in 0..<6 {
        banks.append(dump[pos..<pos + (16 << 10)])
        pos += 16 << 10
      }
      let vramResult = loadVram(
        banks: banks, vramMapTexture: vramMapTexture, vramMapTexpal: vramMapTexpal)
      vramTex = vramResult.vramTex
      vramPal = vramResult.vramPal
    case "DISP":
      pos += 4
    case "TOON":
      pos += 2 * 32
    default:
      fatalError("invalid tag \(op)?!")
    }
  }
  print("imported \(verts.count) vertices")
  return MelonRipperRip(
    verts: verts, uvs: uvs, facesTriangle: facesTriangle, facesQuad: facesQuad,
    faceMaterialsTriangle: faceMaterialsTriangle, faceMaterialsQuad: faceMaterialsQuad,
    materials: materials,
    vramTex: vramTex,
    vramPal: vramPal)
}

struct VramLoadResult {
  let vramTex: Data
  let vramPal: [UInt16]
}

func loadVram(banks: [Data], vramMapTexture: [Int], vramMapTexpal: [Int]) -> VramLoadResult {
  var vramTex = Data()
  var vramPal = Data()
  for i in 0..<4 {
    let mask = vramMapTexture[i]
    if (mask & (1 << 0)) != 0 {
      vramTex += banks[0]
    } else if (mask & (1 << 1)) != 0 {
      vramTex += banks[1]
    } else if (mask & (1 << 2)) != 0 {
      vramTex += banks[2]
    } else if (mask & (1 << 3)) != 0 {
      vramTex += banks[3]
    } else {
      vramTex += Data(count: 128 << 10)
    }
  }
  for i in 0..<8 {
    let mask = vramMapTexpal[i]
    if (mask & (1 << 4)) != 0 {
      vramPal += banks[4 + (i & 3)]
    } else if (mask & (1 << 5)) != 0 {
      vramPal += banks[8]
    } else if (mask & (1 << 6)) != 0 {
      vramPal += banks[9]
    } else {
      vramPal += Data(count: 16 << 10)
    }
  }
  var vramPalUint16 = [UInt16](repeating: 0, count: vramPal.count / 2)
  for i in 0..<vramPalUint16.count {
    vramPalUint16[i] = UInt16(Int(vramPal[i * 2]) | (Int(vramPal[i * 2 + 1]) << 8))
  }
  return VramLoadResult(vramTex: vramTex, vramPal: vramPalUint16)
}

struct MelonRipperDecodedTexture {
  let pixels: Data
  let width: Int
  let height: Int
  let isOpaque: Bool
}

func decodeTexture(rip: MelonRipperRip, texparam: Int, texpal: Int) -> MelonRipperDecodedTexture? {
  var texpal = texpal

  var color = [UInt16]()
  var alpha = [UInt8]()

  let vramaddr = (texparam & 0xffff) << 3
  let width = 8 << ((texparam >> 20) & 7)
  let height = 8 << ((texparam >> 23) & 7)
  let alpha0 = UInt8((texparam & (1 << 29)) != 0 ? 0 : 31)
  let texformat = (texparam >> 26) & 7
  let vramTex = rip.vramTex
  let vramPal = rip.vramPal

  switch texformat {
  case 0:
    return nil
  case 1:  // A3I5
    texpal <<= 3
    for addr in vramaddr..<vramaddr + width * height {
      let pixel = Int(vramTex[addr & 0x7FFFF])
      color.append(vramPal[(texpal + (pixel & 0x1F)) & 0xFFFF])
      alpha.append(UInt8(((pixel >> 3) & 0x1C) + (pixel >> 6)))
    }
  case 6:  // A5I3
    texpal <<= 3
    for addr in vramaddr..<vramaddr + width * height {
      let pixel = Int(vramTex[addr & 0x7FFFF])
      color.append(vramPal[(texpal + (pixel & 0x7)) & 0xFFFF])
      alpha.append(UInt8(pixel >> 3))
    }
  case 2:  // 4-color
    texpal <<= 2
    for addr in vramaddr..<vramaddr + width * height / 4 {
      let pixelx4 = Int(vramTex[addr & 0x7FFFF])
      let p0 = pixelx4 & 0x3
      let p1 = (pixelx4 >> 2) & 0x3
      let p2 = (pixelx4 >> 4) & 0x3
      let p3 = pixelx4 >> 6

      color.append(vramPal[(texpal + p0) & 0xFFFF])
      color.append(vramPal[(texpal + p1) & 0xFFFF])
      color.append(vramPal[(texpal + p2) & 0xFFFF])
      color.append(vramPal[(texpal + p3) & 0xFFFF])

      alpha.append(p0 == 0 ? alpha0 : 31)
      alpha.append(p1 == 0 ? alpha0 : 31)
      alpha.append(p2 == 0 ? alpha0 : 31)
      alpha.append(p3 == 0 ? alpha0 : 31)
    }
  case 3:  // 16-color
    texpal <<= 3
    for addr in vramaddr..<vramaddr + width * height / 2 {
      let pixelx2 = Int(vramTex[addr & 0x7FFFF])
      let p0 = pixelx2 & 0xF
      let p1 = pixelx2 >> 4

      color.append(vramPal[(texpal + p0) & 0xFFFF])
      color.append(vramPal[(texpal + p1) & 0xFFFF])

      alpha.append(p0 == 0 ? alpha0 : 31)
      alpha.append(p1 == 0 ? alpha0 : 31)
    }

  case 4:  // 256-color
    texpal <<= 3
    for addr in vramaddr..<vramaddr + width * height {
      let pixel = Int(vramTex[addr & 0x7FFFF])
      color.append(vramPal[(texpal + pixel) & 0xFFFF])
      alpha.append(pixel == 0 ? alpha0 : 31)
    }

  case 7:  // direct color
    for addr in stride(from: vramaddr, to: vramaddr + width * height * 2, by: 2) {
      var pixel = Int(rip.vramTex[addr & 0x7FFFF])
      pixel |= Int(rip.vramTex[(addr + 1) & 0x7FFFF]) << 8
      color.append(UInt16(pixel))
      alpha.append((pixel & 0x8000) != 0 ? 31 : 0)
    }
  case 5:  // compressed
    color = [UInt16](repeating: 0, count: width * height)
    alpha = [UInt8](repeating: 0, count: width * height)
    var blockColor: [UInt16] = [0, 0, 0, 0]
    var blockAlpha: [UInt8] = [31, 31, 31, 31]
    var xOfs = 0
    var yOfs = 0

    texpal <<= 3

    for addr in stride(from: vramaddr, to: vramaddr + width * height / 4, by: 4) {

      // Read slot1 data for this block

      var slot1addr = 0x20000 + ((addr & 0x1FFFC) >> 1)
      if addr >= 0x40000 {
        slot1addr += 0x10000
      }

      var palinfo = Int(vramTex[slot1addr & 0x7FFFF])
      palinfo |= Int(vramTex[(slot1addr + 1) & 0x7FFFF]) << 8
      let paloffset = texpal + ((palinfo & 0x3FFF) << 1)
      let palmode = palinfo >> 14

      // Calculate block CLUT

      let col0 = vramPal[(paloffset) & 0xFFFF]
      let col1 = vramPal[(paloffset + 1) & 0xFFFF]
      blockColor[0] = col0
      blockColor[1] = col1
      blockAlpha[3] = palmode >= 2 ? 31 : 0

      if palmode == 0 {
        blockColor[2] = vramPal[(paloffset + 2) & 0xFFFF]
        blockColor[3] = 0
      }

      else if palmode == 2 {
        blockColor[2] = vramPal[(paloffset + 2) & 0xFFFF]
        blockColor[3] = vramPal[(paloffset + 3) & 0xFFFF]
      } else if palmode == 1 {
        let r0 = col0 & 0x001F
        let g0 = col0 & 0x03E0
        let b0 = col0 & 0x7C00
        let r1 = col1 & 0x001F
        let g1 = col1 & 0x03E0
        let b1 = col1 & 0x7C00

        let r2 = (r0 + r1) >> 1
        let g2 = ((g0 + g1) >> 1) & 0x03E0
        let b2 = ((b0 + b1) >> 1) & 0x7C00

        blockColor[2] = r2 | g2 | b2
        blockColor[3] = 0

      } else {
        let r0 = Int(col0 & 0x001F)
        let g0 = Int(col0 & 0x03E0)
        let b0 = Int(col0 & 0x7C00)
        let r1 = Int(col1 & 0x001F)
        let g1 = Int(col1 & 0x03E0)
        let b1 = Int(col1 & 0x7C00)

        let r2 = (r0 * 5 + r1 * 3) >> 3
        let g2 = ((g0 * 5 + g1 * 3) >> 3) & 0x03E0
        let b2 = ((b0 * 5 + b1 * 3) >> 3) & 0x7C00

        let r3 = (r0 * 3 + r1 * 5) >> 3
        let g3 = ((g0 * 3 + g1 * 5) >> 3) & 0x03E0
        let b3 = ((b0 * 3 + b1 * 5) >> 3) & 0x7C00

        blockColor[2] = UInt16(r2 | g2 | b2)
        blockColor[3] = UInt16(r3 | g3 | b3)
      }

      // Read block of 4x4 pixels at addr
      // 2bpp indices into the block CLUT

      for y in 0..<4 {
        let ofs = yOfs + y * width + xOfs

        let pixelx4 = Int(vramTex[(addr + y) & 0x7FFFF])

        let p0 = pixelx4 & 0x3
        let p1 = (pixelx4 >> 2) & 0x3
        let p2 = (pixelx4 >> 4) & 0x3
        let p3 = pixelx4 >> 6

        color[ofs] = UInt16(blockColor[p0])
        color[ofs + 1] = blockColor[p1]
        color[ofs + 2] = blockColor[p2]
        color[ofs + 3] = blockColor[p3]

        alpha[ofs] = blockAlpha[p0]
        alpha[ofs + 1] = blockAlpha[p1]
        alpha[ofs + 2] = blockAlpha[p2]
        alpha[ofs + 3] = blockAlpha[p3]
      }

      // Advance to next block position

      xOfs += 4
      if xOfs == width {
        xOfs = 0
        yOfs += 4 * width
      }
    }
  default:
    fatalError("not implemented")
  }

  // Decode to floats
  // Also reverse the rows so the image is right-side-up
  // zhuowei: use 8-bit instead
  var pixels = Data(capacity: width * height * 4)
  for t in 0..<height {
    for i in t * width..<(t + 1) * width {
      let c = Int(color[i])
      let a = Int(alpha[i])
      let r = c & 0x1f
      let g = (c >> 5) & 0x1f
      let b = (c >> 10) & 0x1f
      pixels.append(contentsOf: [
        UInt8(r * 0xff / 0x1f), UInt8(g * 0xff / 0x1f), UInt8(b * 0xff / 0x1f),
        UInt8(a * 0xff / 0x1f),
      ])
    }
  }

  let isOpaque = alpha.allSatisfy({ $0 == 31 })

  return MelonRipperDecodedTexture(pixels: pixels, width: width, height: height, isOpaque: isOpaque)
}

struct MelonRipperTextureKey: Hashable {
  let vramaddr: Int
  let width: Int
  let height: Int
  let alpha0: Int
  let texformat: Int
  let texpal: Int
}

func realityKitModelFromRip(rip: MelonRipperRip) -> ModelComponent {
  // https://maxxfrazer.medium.com/getting-started-with-realitykit-procedural-geometries-5dd9eca659ef
  var descr = MeshDescriptor(name: "tritri")
  descr.positions = MeshBuffers.Positions(rip.verts)
  descr.textureCoordinates = MeshBuffers.TextureCoordinates(rip.uvs)
  descr.primitives = .trianglesAndQuads(triangles: rip.facesTriangle, quads: rip.facesQuad)
  descr.materials = .perFace(rip.faceMaterialsTriangle + rip.faceMaterialsQuad)
  let materials = realityKitMaterialsFromRip(rip: rip)
  let modelComponent = ModelComponent(
    mesh: try! .generate(from: [descr]),
    materials: materials
  )
  return modelComponent
}

func realityKitMaterialsFromRip(rip: MelonRipperRip) -> [Material] {
  var outputMaterials = [Material?](repeating: nil, count: rip.materials.count)
  for (materialKey, materialIndex) in rip.materials {
    // TODO(zhuowei): is caching necessary here?
    outputMaterials[materialIndex] = createMaterial(
      rip: rip, texparam: materialKey.texparam, texpal: materialKey.texpal,
      polygonAttr: materialKey.polygonAttr)
  }
  return outputMaterials.map({ $0! })
}

func createMaterial(rip: MelonRipperRip, texparam: Int, texpal: Int, polygonAttr: Int) -> Material {
  guard let decodedImage = decodeTexture(rip: rip, texparam: texparam, texpal: texpal) else {
    return SimpleMaterial(color: .orange, isMetallic: false)
  }
  let cgImage = CGImage(
    width: decodedImage.width, height: decodedImage.height, bitsPerComponent: 8, bitsPerPixel: 32,
    bytesPerRow: decodedImage.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(
      rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.last.rawValue),
    provider: CGDataProvider(data: decodedImage.pixels as CFData)!, decode: nil,
    shouldInterpolate: false,
    intent: .defaultIntent)!
  let texture = MaterialParameters.Texture(
    try! .generate(
      from: cgImage,
      options: TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAll)))
  let color = PhysicallyBasedMaterial.BaseColor(
    tint: .white,
    texture: texture)
  var material = SimpleMaterial(color: .orange, isMetallic: false)
  material.color = color
  return material
}

// https://github.com/LinusHenze/Fugu14/blob/7cba721b6d62555dd0c0b47416ee103ee112576e/arm/shared/JailbreakUtils/Sources/JailbreakUtils/utils.swift#LL42C1
extension Data {
  /**
     * Convert raw data directly into an object
     *
     * - warning: This function is UNSAFE as it could be used to deserialize pointers. Use with caution!
     *
     * - parameter type: The type to convert the raw data into
     */
  public func getGeneric<Object: Any>(type: Object.Type, offset: UInt = 0) -> Object {
    guard (Int(offset) + MemoryLayout<Object>.size) <= self.count else {
      fatalError("Tried to read out of bounds!")
    }

    return withUnsafeBytes { ptr in
      ptr.baseAddress!.advanced(by: Int(offset)).assumingMemoryBound(to: Object.self).pointee
    }
  }

  public func toString(encoding: String.Encoding = .utf8, nullTerminated: Bool = false) -> String {
    if nullTerminated, let index = self.firstIndex(of: 0) {
      let new = self[..<index]
      return new.toString(encoding: encoding)
    }

    guard let str = String(data: self, encoding: encoding) else {
      //throw StringDecodingError(self, encoding: encoding)
      fatalError("i hate strings")
    }

    return str
  }
}
