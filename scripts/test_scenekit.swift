import SceneKit
import AppKit

let scene = SCNScene()

// Background
scene.background.contents = NSColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0)

// Camera
let cameraNode = SCNNode()
let camera = SCNCamera()
camera.wantsHDR = true
camera.bloomThreshold = 0.8
camera.bloomIntensity = 1.2
camera.bloomBlurRadius = 15.0
camera.fieldOfView = 38
cameraNode.camera = camera
cameraNode.position = SCNVector3(0, 0, 8)
scene.rootNode.addChildNode(cameraNode)

// Central Squircle
let box = SCNBox(width: 2.2, height: 2.2, length: 2.2, chamferRadius: 0.6)
let boxNode = SCNNode(geometry: box)
boxNode.rotation = SCNVector4(1, 1, 0, Float.pi / 5)

let mat = SCNMaterial()
mat.lightingModel = .physicallyBased
mat.diffuse.contents = NSColor(white: 0.05, alpha: 1.0)
mat.roughness.contents = 0.12
mat.metalness.contents = 0.85
mat.clearCoat.contents = 1.0
mat.clearCoatRoughness.contents = 0.05
box.materials = [mat]
scene.rootNode.addChildNode(boxNode)

// Torus Rings
let ring1 = SCNTorus(ringRadius: 2.4, pipeRadius: 0.08)
let ringMat1 = SCNMaterial()
ringMat1.lightingModel = .physicallyBased
ringMat1.diffuse.contents = NSColor.white
ringMat1.metalness.contents = 0.95
ringMat1.roughness.contents = 0.05
ring1.materials = [ringMat1]
let ringNode1 = SCNNode(geometry: ring1)
ringNode1.rotation = SCNVector4(1, 0.4, 0.2, Float.pi / 3)
scene.rootNode.addChildNode(ringNode1)

// Lights
let keyLightNode = SCNNode()
let keyLight = SCNLight()
keyLight.type = .directional
keyLight.color = NSColor.white
keyLight.intensity = 1800
keyLightNode.light = keyLight
keyLightNode.position = SCNVector3(5, 5, 8)
keyLightNode.look(at: SCNVector3(0, 0, 0))
scene.rootNode.addChildNode(keyLightNode)

let rimLightNode = SCNNode()
let rimLight = SCNLight()
rimLight.type = .spot
rimLight.color = NSColor.white
rimLight.intensity = 3000
rimLight.spotOuterAngle = 60
rimLightNode.light = rimLight
rimLightNode.position = SCNVector3(-6, -4, -3)
rimLightNode.look(at: SCNVector3(0, 0, 0))
scene.rootNode.addChildNode(rimLightNode)

// Render
let device = MTLCreateSystemDefaultDevice()
let renderer = SCNRenderer(device: device, options: nil)
renderer.scene = scene
let size = CGSize(width: 1024, height: 1024)
let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)

if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .jpeg, properties: [:]) {
    try? data.write(to: URL(fileURLWithPath: "test_render.jpg"))
    print("Success: test_render.jpg written, size: \(data.count) bytes")
}
