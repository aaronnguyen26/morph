import SceneKit
import AppKit

func renderRings(isFront: Bool, filename: String) {
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

    let ringMat1 = SCNMaterial()
    ringMat1.lightingModel = .physicallyBased
    ringMat1.diffuse.contents = NSColor(white: 0.95, alpha: 1.0)
    ringMat1.metalness.contents = 0.98
    ringMat1.roughness.contents = 0.05
    ringMat1.clearCoat.contents = 1.0

    let ring1 = SCNTorus(ringRadius: 2.25, pipeRadius: 0.038)
    ring1.materials = [ringMat1]
    let ringNode1 = SCNNode(geometry: ring1)
    ringNode1.rotation = SCNVector4(1, 0.45, 0.25, Float.pi / 3.1)
    scene.rootNode.addChildNode(ringNode1)

    let ringMat2 = SCNMaterial()
    ringMat2.lightingModel = .physicallyBased
    ringMat2.diffuse.contents = NSColor(white: 0.88, alpha: 0.85)
    ringMat2.metalness.contents = 0.85
    ringMat2.roughness.contents = 0.12

    let ring2 = SCNTorus(ringRadius: 2.50, pipeRadius: 0.026)
    ring2.materials = [ringMat2]
    let ringNode2 = SCNNode(geometry: ring2)
    ringNode2.rotation = SCNVector4(-0.45, 1, 0.25, Float.pi / 2.7)
    scene.rootNode.addChildNode(ringNode2)

    // Dots
    let dotPositions: [(Float, Float, Float, Float)] = [
        (1.8, 1.35, 0.5, 0.09),
        (-1.85, -1.05, 0.4, 0.11),
        (0.28, 2.15, -0.3, 0.075),
        (-1.15, 1.75, 0.6, 0.06),
        (1.45, -1.55, -0.4, 0.08),
        (-2.05, 0.45, -0.5, 0.065),
        (0.75, -2.05, 0.3, 0.07)
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

    // Set clipping planes or mask for front vs back
    // Camera is at z = 7.8, scene center is z = 0.
    // If isFront: nearClippingPlane = 0.1, farClippingPlane = 7.8 (only z >= 0)
    // If isBack: nearClippingPlane = 7.8, farClippingPlane = 20.0 (only z < 0)
    if isFront {
        camera.zNear = 0.1
        camera.zFar = 7.8
    } else {
        camera.zNear = 7.8
        camera.zFar = 20.0
    }

    let keyLight = SCNLight()
    keyLight.type = .directional
    keyLight.color = NSColor.white
    keyLight.intensity = 2000
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
        try? data.write(to: URL(fileURLWithPath: filename))
    }
}

renderRings(isFront: false, filename: "rings_back.png")
renderRings(isFront: true, filename: "rings_front.png")
print("Rings front and back rendered successfully.")
