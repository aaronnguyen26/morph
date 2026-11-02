import SceneKit
import AppKit

let width = 1024
let height = 1024

let scene = SCNScene()
scene.background.contents = NSColor.clear // Transparent

let cameraNode = SCNNode()
let camera = SCNCamera()
camera.wantsHDR = true
camera.fieldOfView = 42
cameraNode.camera = camera
cameraNode.position = SCNVector3(0, 0, 7.5)
scene.rootNode.addChildNode(cameraNode)

// Gyroscopic Orbital Rings around Morphy
let ringMat1 = SCNMaterial()
ringMat1.lightingModel = .physicallyBased
ringMat1.diffuse.contents = NSColor(white: 0.95, alpha: 1.0)
ringMat1.metalness.contents = 0.98
ringMat1.roughness.contents = 0.04
ringMat1.clearCoat.contents = 1.0

let ring1 = SCNTorus(ringRadius: 2.35, pipeRadius: 0.038)
ring1.materials = [ringMat1]
let ringNode1 = SCNNode(geometry: ring1)
ringNode1.rotation = SCNVector4(1, 0.4, 0.3, Float.pi / 3.2)
scene.rootNode.addChildNode(ringNode1)

let ringMat2 = SCNMaterial()
ringMat2.lightingModel = .physicallyBased
ringMat2.diffuse.contents = NSColor(white: 0.85, alpha: 0.7) // Frosted glass / silver
ringMat2.metalness.contents = 0.80
ringMat2.roughness.contents = 0.15

let ring2 = SCNTorus(ringRadius: 2.60, pipeRadius: 0.024)
ring2.materials = [ringMat2]
let ringNode2 = SCNNode(geometry: ring2)
ringNode2.rotation = SCNVector4(-0.5, 1, 0.2, Float.pi / 2.6)
scene.rootNode.addChildNode(ringNode2)

// Orbiting Constellation Dots (OpenAI Dots inspiration)
let dotPositions: [(Float, Float, Float, Float)] = [
    (1.8, 1.4, 0.5, 0.09),
    (-1.9, -1.1, 0.4, 0.11),
    (0.3, 2.2, -0.3, 0.075),
    (-1.2, 1.8, 0.6, 0.06),
    (1.5, -1.6, -0.4, 0.08),
    (-2.1, 0.5, -0.5, 0.065),
    (0.8, -2.1, 0.3, 0.07)
]

let dotMat = SCNMaterial()
dotMat.lightingModel = .physicallyBased
dotMat.diffuse.contents = NSColor.white
dotMat.metalness.contents = 0.95
dotMat.roughness.contents = 0.05

for (x, y, z, r) in dotPositions {
    let sphere = SCNSphere(radius: CGFloat(r))
    sphere.materials = [dotMat]
    let node = SCNNode(geometry: sphere)
    node.position = SCNVector3(x, y, z)
    scene.rootNode.addChildNode(node)
}

// Studio Lighting
let keyLight = SCNLight()
keyLight.type = .directional
keyLight.color = NSColor.white
keyLight.intensity = 1800
let keyLightNode = SCNNode()
keyLightNode.light = keyLight
keyLightNode.position = SCNVector3(4, 5, 6)
keyLightNode.look(at: SCNVector3(0, 0, 0))
scene.rootNode.addChildNode(keyLightNode)

let rimLight = SCNLight()
rimLight.type = .directional
rimLight.color = NSColor.white
rimLight.intensity = 1500
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
    try? data.write(to: URL(fileURLWithPath: "orbital_rings_overlay.png"))
    print("Orbital rings rendered to orbital_rings_overlay.png")
}
