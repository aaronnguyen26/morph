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

// Frosted Glass & Obsidian Squircle Stage Pedestal (Dynamic Island squircle)
let stageMat = SCNMaterial()
stageMat.lightingModel = .physicallyBased
stageMat.diffuse.contents = NSColor(white: 0.12, alpha: 0.9)
stageMat.metalness.contents = 0.35
stageMat.roughness.contents = 0.08
stageMat.clearCoat.contents = 1.0
stageMat.clearCoatRoughness.contents = 0.04

// Chamfered squircle box stage
let stageBox = SCNBox(width: 3.4, height: 0.28, length: 1.8, chamferRadius: 0.12)
stageBox.materials = [stageMat]
let stageNode = SCNNode(geometry: stageBox)
stageNode.position = SCNVector3(0, -2.1, 0)
stageNode.rotation = SCNVector4(1, 0, 0, Float.pi * 0.08)
scene.rootNode.addChildNode(stageNode)

// Chrome Bevel Inset Rim around stage
let rimMat = SCNMaterial()
rimMat.lightingModel = .physicallyBased
rimMat.diffuse.contents = NSColor.white
rimMat.metalness.contents = 0.98
rimMat.roughness.contents = 0.04

let stageRim = SCNBox(width: 3.44, height: 0.06, length: 1.84, chamferRadius: 0.04)
stageRim.materials = [rimMat]
let rimNode = SCNNode(geometry: stageRim)
rimNode.position = SCNVector3(0, -1.94, 0)
rimNode.rotation = SCNVector4(1, 0, 0, Float.pi * 0.08)
scene.rootNode.addChildNode(rimNode)

// Studio Lights
let keyLight = SCNLight()
keyLight.type = .directional
keyLight.color = NSColor.white
keyLight.intensity = 2200
let keyLightNode = SCNNode()
keyLightNode.light = keyLight
keyLightNode.position = SCNVector3(4, 6, 6)
keyLightNode.look(at: SCNVector3(0, -2, 0))
scene.rootNode.addChildNode(keyLightNode)

let rimLight = SCNLight()
rimLight.type = .directional
rimLight.color = NSColor.white
rimLight.intensity = 1800
let rimLightNode = SCNNode()
rimLightNode.light = rimLight
rimLightNode.position = SCNVector3(-5, -3, -3)
rimLightNode.look(at: SCNVector3(0, -2, 0))
scene.rootNode.addChildNode(rimLightNode)

let device = MTLCreateSystemDefaultDevice()
let renderer = SCNRenderer(device: device, options: nil)
renderer.scene = scene
let size = CGSize(width: width, height: height)
let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)

if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
    try? data.write(to: URL(fileURLWithPath: "stage_pedestal.png"))
    print("Stage pedestal rendered to stage_pedestal.png")
}
