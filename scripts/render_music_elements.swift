import SceneKit
import AppKit

let width = 1024
let height = 1024

let scene = SCNScene()
scene.background.contents = NSColor.clear

let cameraNode = SCNNode()
let camera = SCNCamera()
camera.wantsHDR = true
camera.fieldOfView = 44
cameraNode.camera = camera
cameraNode.position = SCNVector3(0, 0, 7.8)
scene.rootNode.addChildNode(cameraNode)

let chromeMat = SCNMaterial()
chromeMat.lightingModel = .physicallyBased
chromeMat.diffuse.contents = NSColor.white
chromeMat.metalness.contents = 0.98
chromeMat.roughness.contents = 0.04
chromeMat.clearCoat.contents = 1.0

// Concentric Soundwave Arcs (floating beside headphones)
let waveRadius1: Float = 0.65
let wave1 = SCNTorus(ringRadius: CGFloat(waveRadius1), pipeRadius: 0.024)
wave1.materials = [chromeMat]
let waveNodeLeft1 = SCNNode(geometry: wave1)
waveNodeLeft1.position = SCNVector3(-2.2, 0.4, 0.2)
waveNodeLeft1.rotation = SCNVector4(0, 1, 0, Float.pi * 0.45)
scene.rootNode.addChildNode(waveNodeLeft1)

let waveNodeRight1 = SCNNode(geometry: wave1)
waveNodeRight1.position = SCNVector3(2.2, 0.4, 0.2)
waveNodeRight1.rotation = SCNVector4(0, 1, 0, -Float.pi * 0.45)
scene.rootNode.addChildNode(waveNodeRight1)

let waveRadius2: Float = 0.95
let wave2 = SCNTorus(ringRadius: CGFloat(waveRadius2), pipeRadius: 0.018)
wave2.materials = [chromeMat]
let waveNodeLeft2 = SCNNode(geometry: wave2)
waveNodeLeft2.position = SCNVector3(-2.6, 0.4, 0.1)
waveNodeLeft2.rotation = SCNVector4(0, 1, 0, Float.pi * 0.45)
scene.rootNode.addChildNode(waveNodeLeft2)

let waveNodeRight2 = SCNNode(geometry: wave2)
waveNodeRight2.position = SCNVector3(2.6, 0.4, 0.1)
waveNodeRight2.rotation = SCNVector4(0, 1, 0, -Float.pi * 0.45)
scene.rootNode.addChildNode(waveNodeRight2)

// Floating Zero-G Musical Spheres / Beat Pips
let beatPositions: [(Float, Float, Float, Float)] = [
    (1.7, 1.6, 0.4, 0.09),
    (-1.6, 1.7, 0.3, 0.08),
    (2.1, -0.6, 0.2, 0.07),
    (-2.0, -0.7, 0.2, 0.065),
    (0.4, 2.3, -0.2, 0.06),
    (-0.5, 2.4, -0.2, 0.055)
]

for (x, y, z, r) in beatPositions {
    let sphere = SCNSphere(radius: CGFloat(r))
    sphere.materials = [chromeMat]
    let node = SCNNode(geometry: sphere)
    node.position = SCNVector3(x, y, z)
    scene.rootNode.addChildNode(node)
}

// Lighting
let keyLight = SCNLight()
keyLight.type = .directional
keyLight.color = NSColor.white
keyLight.intensity = 2200
let keyLightNode = SCNNode()
keyLightNode.light = keyLight
keyLightNode.position = SCNVector3(4, 5, 6)
keyLightNode.look(at: SCNVector3(0, 0, 0))
scene.rootNode.addChildNode(keyLightNode)

let rimLight = SCNLight()
rimLight.type = .directional
rimLight.color = NSColor.white
rimLight.intensity = 1800
let rimLightNode = SCNNode()
rimLightNode.light = rimLight
rimLightNode.position = SCNVector3(-5, -4, -3)
rimLightNode.look(at: SCNVector3(0, 0, 0))
scene.rootNode.addChildNode(rimLightNode)

let device = MTLCreateSystemDefaultDevice()
let renderer = SCNRenderer(device: device, options: nil)
renderer.scene = scene
let size = CGSize(width: width, height: height)
let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)

if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
    try? data.write(to: URL(fileURLWithPath: "soundwave_elements.png"))
    print("Soundwave elements rendered to soundwave_elements.png")
}
