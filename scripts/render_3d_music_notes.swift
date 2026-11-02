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
chromeMat.roughness.contents = 0.05
chromeMat.clearCoat.contents = 1.0

// Helper to create a 3D eighth note
func createNote(x: Float, y: Float, z: Float, scale: Float, rotZ: Float) -> SCNNode {
    let noteNode = SCNNode()
    noteNode.position = SCNVector3(x, y, z)
    noteNode.rotation = SCNVector4(0, 0, 1, rotZ)
    noteNode.scale = SCNVector3(scale, scale, scale)
    
    // Note head (tilted squashed sphere)
    let head = SCNSphere(radius: 0.22)
    head.materials = [chromeMat]
    let headNode = SCNNode(geometry: head)
    headNode.scale = SCNVector3(1.2, 0.85, 0.7)
    headNode.rotation = SCNVector4(0, 0, 1, Float.pi * 0.15)
    noteNode.addChildNode(headNode)
    
    // Note stem
    let stem = SCNCylinder(radius: 0.032, height: 0.85)
    stem.materials = [chromeMat]
    let stemNode = SCNNode(geometry: stem)
    stemNode.position = SCNVector3(0.18, 0.42, 0)
    noteNode.addChildNode(stemNode)
    
    // Note flag (curved hook at top)
    let flag = SCNTorus(ringRadius: 0.22, pipeRadius: 0.035)
    flag.materials = [chromeMat]
    let flagNode = SCNNode(geometry: flag)
    flagNode.position = SCNVector3(0.32, 0.78, 0)
    flagNode.rotation = SCNVector4(0, 1, 0, Float.pi * 0.45)
    noteNode.addChildNode(flagNode)
    
    return noteNode
}

// Add 3 notes floating playfully around Focus Morphy
let note1 = createNote(x: 2.1, y: 1.5, z: 0.3, scale: 0.95, rotZ: Float.pi * 0.1)
scene.rootNode.addChildNode(note1)

let note2 = createNote(x: -2.0, y: 1.6, z: 0.2, scale: 0.85, rotZ: -Float.pi * 0.15)
scene.rootNode.addChildNode(note2)

let note3 = createNote(x: 2.3, y: -0.4, z: 0.4, scale: 0.7, rotZ: -Float.pi * 0.08)
scene.rootNode.addChildNode(note3)

// Floating sparkle beads
for (x, y, z, r) in [(Float(1.5), Float(2.2), Float(0.2), Float(0.065)),
                    (Float(-1.4), Float(2.3), Float(0.1), Float(0.055)),
                    (Float(2.5), Float(0.6), Float(0.3), Float(0.05)),
                    (Float(-2.3), Float(0.5), Float(0.2), Float(0.06))] {
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
    try? data.write(to: URL(fileURLWithPath: "chrome_notes.png"))
    print("Notes rendered to chrome_notes.png")
}
