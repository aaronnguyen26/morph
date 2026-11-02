import Metal
import AppKit

let width = 1024
let height = 1024

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("No Metal device")
}

let metalSource = """
#include <metal_stdlib>
using namespace metal;

float sdSphere(float3 p, float r) {
    return length(p) - r;
}

float sdRoundBox(float3 p, float3 b, float r) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdTorus(float3 p, float2 t) {
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Smooth minimum for fluid organic morphing
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// 3D rotation matrix around Y and X
float3 rotateY(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

float3 rotateX(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

float3 rotateZ(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

// Scene Distance Field: The Frosted Crystal Squircle Prism & Floating Core
float mapScene(float3 p, thread int &matId) {
    float3 pRot = rotateY(rotateX(p, 0.35), 0.55);
    
    // Core floating glowing sphere
    float dCore = sdSphere(pRot, 0.55);
    
    // Outer rounded squircle prism
    float dBox = sdRoundBox(pRot, float3(1.1, 1.1, 1.1), 0.35);
    
    // Orbital sleek ring
    float3 pRing = rotateZ(pRot, 0.7);
    float dRing = sdTorus(pRing, float2(1.9, 0.045));
    
    // Floating zero-g satellite micro-droplets
    float dDrop1 = sdSphere(p - float3(1.8, 1.2, 0.5), 0.12);
    float dDrop2 = sdSphere(p - float3(-1.7, -1.0, 0.3), 0.16);
    float dDrop3 = sdSphere(p - float3(0.3, 2.0, -0.4), 0.09);
    float dDrop4 = sdSphere(p - float3(-0.8, 1.8, 0.8), 0.07);
    float dDrops = min(min(dDrop1, dDrop2), min(dDrop3, dDrop4));
    
    float dOuter = min(dBox, min(dRing, dDrops));
    
    if (dCore < dOuter) {
        matId = 1; // Core
        return dCore;
    } else {
        if (dOuter == dRing || dOuter == dDrops) {
            matId = 2; // Chrome ring & droplets
        } else {
            matId = 3; // Smoked Glass / Obsidian Box
        }
        return dOuter;
    }
}

float3 calcNormal(float3 p) {
    int dummyMat;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        mapScene(p + e.xyy, dummyMat) - mapScene(p - e.xyy, dummyMat),
        mapScene(p + e.yxy, dummyMat) - mapScene(p - e.yxy, dummyMat),
        mapScene(p + e.yyx, dummyMat) - mapScene(p - e.yyx, dummyMat)
    ));
}

float calcAO(float3 p, float3 n) {
    float occ = 0.0;
    float sca = 1.0;
    int dummyMat;
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = mapScene(p + h * n, dummyMat);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

kernel void renderKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = outTexture.get_width();
    uint height = outTexture.get_height();
    if (gid.x >= width || gid.y >= height) return;
    
    float3 totalColor = float3(0.0);
    int numSamples = 2; // 2x2 MSAA
    
    for (int sx = 0; sx < numSamples; sx++) {
        for (int sy = 0; sy < numSamples; sy++) {
            float2 offset = float2(float(sx) / float(numSamples), float(sy) / float(numSamples));
            float2 uv = (float2(gid) + offset - float2(width, height) * 0.5) / float(height);
            uv.y = -uv.y; // Flip Y
            
            float3 ro = float3(0.0, 0.0, 5.2);
            float3 rd = normalize(float3(uv, -1.8));
            
            // Raymarch
            float t = 0.0;
            int matId = 0;
            bool hit = false;
            
            for (int i = 0; i < 140; i++) {
                float3 p = ro + rd * t;
                float d = mapScene(p, matId);
                if (d < 0.001) {
                    hit = true;
                    break;
                }
                t += d * 0.75;
                if (t > 15.0) break;
            }
            
            float3 col = float3(0.03, 0.03, 0.04) * (1.0 - length(uv) * 0.6); // Dark luxury studio gradient
            
            if (hit) {
                float3 p = ro + rd * t;
                float3 n = calcNormal(p);
                float3 v = -rd;
                float ao = calcAO(p, n);
                
                // Studio lighting
                float3 lightPos1 = float3(4.0, 5.0, 4.0);
                float3 lightDir1 = normalize(lightPos1 - p);
                float diff1 = max(dot(n, lightDir1), 0.0);
                float3 h1 = normalize(lightDir1 + v);
                float spec1 = pow(max(dot(n, h1), 0.0), 40.0);
                
                // Pure rim light from back/side
                float3 lightPos2 = float3(-5.0, -3.0, -2.0);
                float3 lightDir2 = normalize(lightPos2 - p);
                float rim = pow(clamp(1.0 - dot(n, v), 0.0, 1.0), 3.5);
                
                // Fresnel
                float fresnel = 0.04 + 0.96 * pow(1.0 - max(dot(n, v), 0.0), 5.0);
                
                if (matId == 1) {
                    // Radiant Core
                    col = float3(1.0, 1.0, 1.0) * (diff1 * 0.3 + 0.85);
                } else if (matId == 2) {
                    // Chrome ring & droplets
                    float3 refl = reflect(rd, n);
                    float reflEnv = pow(max(refl.y, 0.0), 2.0) * 0.8 + pow(abs(refl.x), 3.0) * 0.6;
                    col = float3(0.1) + float3(0.9) * (diff1 * 0.2 + spec1 * 1.5 + rim * 1.8 + fresnel * 0.9 + reflEnv * 0.6);
                } else {
                    // Frosted Obsidian / Smoked Crystal Box
                    float3 baseDark = float3(0.06, 0.06, 0.07);
                    col = baseDark * ao + float3(1.0) * (spec1 * 0.9 + rim * 1.4 + fresnel * 0.7);
                    
                    // Internal core glow transmission
                    float3 pRot = rotateY(rotateX(p, 0.35), 0.55);
                    float distToCore = length(pRot);
                    float coreGlow = clamp(1.0 - (distToCore - 0.55) / 1.0, 0.0, 1.0);
                    col += float3(0.7, 0.7, 0.75) * pow(coreGlow, 2.5) * 0.65;
                }
            } else {
                // Subtle volumetric floor caustic / glow
                float groundY = -1.6;
                if (rd.y < 0.0) {
                    float gt = (groundY - ro.y) / rd.y;
                    if (gt > 0.0) {
                        float3 gp = ro + rd * gt;
                        float shadowDist = length(gp.xz);
                        float groundGlow = exp(-shadowDist * 0.8) * 0.12;
                        col += float3(groundGlow);
                    }
                }
            }
            
            // Subtle bloom / glow around center
            col += float3(0.04) * exp(-length(uv) * 2.2);
            
            totalColor += col;
        }
    }
    
    totalColor /= float(numSamples * numSamples);
    
    // Tone mapping and gamma
    totalColor = totalColor / (totalColor + float3(1.0));
    totalColor = pow(totalColor, float3(1.0 / 2.2));
    
    outTexture.write(float4(totalColor, 1.0), gid);
}
"""

guard let library = try? device.makeLibrary(source: metalSource, options: nil),
      let kernelFunction = library.makeFunction(name: "renderKernel"),
      let pipelineState = try? device.makeComputePipelineState(function: kernelFunction),
      let commandQueue = device.makeCommandQueue() else {
    fatalError("Failed to initialize Metal pipeline")
}

let textureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
textureDesc.usage = [.shaderWrite, .shaderRead]
guard let texture = device.makeTexture(descriptor: textureDesc) else {
    fatalError("Failed to create texture")
}

guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeComputeCommandEncoder() else {
    fatalError("Failed to create command encoder")
}

encoder.setComputePipelineState(pipelineState)
encoder.setTexture(texture, index: 0)

let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
let threadgroupCount = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
encoder.endEncoding()

commandBuffer.commit()
commandBuffer.waitUntilCompleted()

// Read back texture and save as JPEG
var bytes = [UInt8](repeating: 0, count: width * height * 4)
let region = MTLRegionMake2D(0, 0, width, height)
texture.getBytes(&bytes, bytesPerRow: width * 4, from: region, mipmapLevel: 0)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: &bytes,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let cgImage = context.makeImage() else {
    fatalError("Failed to create CGImage")
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
if let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) {
    try? jpegData.write(to: URL(fileURLWithPath: "test_metal_render.jpg"))
    print("Metal render success! Saved test_metal_render.jpg, size: \(jpegData.count) bytes")
}
