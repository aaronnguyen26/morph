import Metal
import AppKit

let width = 1024
let height = 1024

guard let device = MTLCreateSystemDefaultDevice() else { fatalError() }

let metalSource = """
#include <metal_stdlib>
using namespace metal;

float3 rotateX(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}
float3 rotateY(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}
float3 rotateZ(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

float sdSphere(float3 p, float r) { return length(p) - r; }

float sdRoundBox(float3 p, float3 b, float r) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdTorus(float3 p, float2 t) {
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float mapScene4(float3 p, thread int &matId) {
    float3 pRot = rotateY(rotateX(p, 0.45), 0.65);
    
    // Core floating glowing sphere
    float dCore = sdSphere(pRot, 0.38);
    
    // Outer rounded squircle prism
    float dPrism = sdRoundBox(pRot, float3(0.58, 0.58, 0.58), 0.28);
    
    // Fine titanium orbital rings
    float3 pRing1 = rotateZ(rotateX(pRot, 0.75), 0.35);
    float dRing1 = sdTorus(pRing1, float2(1.28, 0.024));
    
    float3 pRing2 = rotateZ(rotateY(pRot, -0.6), -0.4);
    float dRing2 = sdTorus(pRing2, float2(1.42, 0.018));
    
    // Floating zero-g satellite micro-droplets
    float dD1 = sdSphere(p - float3(1.25, 0.85, 0.3), 0.065);
    float dD2 = sdSphere(p - float3(-1.15, -0.75, 0.2), 0.08);
    float dD3 = sdSphere(p - float3(0.15, 1.35, -0.2), 0.05);
    float dD4 = sdSphere(p - float3(-0.7, 1.1, 0.5), 0.04);
    float dD5 = sdSphere(p - float3(0.95, -0.95, -0.3), 0.06);
    float dD6 = sdSphere(p - float3(-1.25, 0.45, -0.4), 0.045);
    float dD7 = sdSphere(p - float3(0.65, 1.2, 0.4), 0.035);
    float dDrops = min(min(min(min(dD1, dD2), min(dD3, dD4)), min(dD5, dD6)), dD7);
    
    float dMetallic = min(min(dRing1, dRing2), dDrops);
    
    if (dCore < min(dPrism, dMetallic)) {
        matId = 1;
        return dCore;
    } else if (dMetallic < dPrism) {
        matId = 2;
        return dMetallic;
    } else {
        matId = 3;
        return dPrism;
    }
}

float3 calcNormal4(float3 p) {
    int dummy;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        mapScene4(p + e.xyy, dummy) - mapScene4(p - e.xyy, dummy),
        mapScene4(p + e.yxy, dummy) - mapScene4(p - e.yxy, dummy),
        mapScene4(p + e.yyx, dummy) - mapScene4(p - e.yyx, dummy)
    ));
}

float calcAO4(float3 p, float3 n) {
    float occ = 0.0;
    float sca = 1.0;
    int dummy;
    for (int i = 0; i < 5; i++) {
        float h = 0.02 + 0.12 * float(i) / 4.0;
        float d = mapScene4(p + h * n, dummy);
        occ += (h - d) * sca;
        sca *= 0.85;
    }
    return clamp(1.0 - 2.5 * occ, 0.0, 1.0);
}

float3 studioEnv(float3 dir) {
    float3 col = float3(0.012, 0.012, 0.015);
    // Soft top light
    float top = smoothstep(0.5, 0.98, dir.y) * smoothstep(0.7, 0.0, abs(dir.x));
    col += float3(1.2) * top;
    // Left rim
    float left = smoothstep(0.6, 0.95, -dir.x) * smoothstep(0.7, 0.0, abs(dir.y));
    col += float3(0.9, 0.95, 1.0) * left * 1.5;
    // Right accent
    float right = smoothstep(0.7, 0.98, dir.x) * smoothstep(0.6, 0.0, abs(dir.y));
    col += float3(0.85) * right * 1.1;
    return col;
}

kernel void renderKernel4(
    texture2d<float, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = outTexture.get_width();
    uint h = outTexture.get_height();
    if (gid.x >= w || gid.y >= h) return;
    
    float3 totalColor = float3(0.0);
    const int aa = 2;
    
    for (int sx = 0; sx < aa; sx++) {
        for (int sy = 0; sy < aa; sy++) {
            float2 offset = float2(float(sx) / float(aa), float(sy) / float(aa));
            float2 uv = (float2(gid) + offset - float2(w, h) * 0.5) / float(h);
            uv.y = -uv.y;
            
            float3 ro = float3(0.0, 0.0, 5.5);
            float3 rd = normalize(float3(uv * 1.35, -1.8));
            
            float t = 0.0;
            int matId = 0;
            bool hit = false;
            
            for (int i = 0; i < 160; i++) {
                float3 p = ro + rd * t;
                float d = mapScene4(p, matId);
                if (d < 0.0006) {
                    hit = true;
                    break;
                }
                t += d * 0.72;
                if (t > 12.0) break;
            }
            
            // Background
            float distCenter = length(uv);
            float vignette = 1.0 - 0.75 * distCenter * distCenter;
            float3 col = float3(0.012, 0.012, 0.015) * vignette;
            
            if (hit) {
                float3 p = ro + rd * t;
                float3 n = calcNormal4(p);
                float3 v = -rd;
                float ao = calcAO4(p, n);
                
                float3 keyDir = normalize(float3(3.5, 5.0, 4.0));
                float diffKey = max(dot(n, keyDir), 0.0);
                float3 hKey = normalize(keyDir + v);
                float specKey = pow(max(dot(n, hKey), 0.0), 38.0);
                
                float rim = pow(clamp(1.0 - dot(n, v), 0.0, 1.0), 3.2);
                float fresnel = 0.04 + 0.96 * pow(clamp(1.0 - max(dot(n, v), 0.0), 0.0, 1.0), 5.0);
                
                float3 refl = reflect(rd, n);
                float3 envCol = studioEnv(refl);
                
                if (matId == 1) {
                    // Radiant internal core
                    col = float3(1.15) * (diffKey * 0.2 + 0.9);
                } else if (matId == 2) {
                    // Chrome rings and droplets
                    col = envCol * 0.9 + float3(1.0) * (specKey * 1.8 + rim * 1.6 + fresnel * 0.9);
                } else {
                    // Smoked Obsidian Glass Prism
                    float3 baseObsidian = float3(0.035, 0.035, 0.04);
                    float specRough = pow(max(dot(n, hKey), 0.0), 14.0) * 0.35;
                    float3 surfaceGlint = envCol * fresnel * 0.8 + float3(1.0) * (specKey * 0.95 + specRough + rim * 1.25);
                    
                    float3 pRot = rotateY(rotateX(p, 0.45), 0.65);
                    float distCore = length(pRot);
                    float innerGlow = clamp(1.0 - (distCore - 0.38) / 0.55, 0.0, 1.0);
                    float3 coreTrans = float3(0.9, 0.92, 0.98) * pow(innerGlow, 2.6) * 1.25;
                    
                    float edgeCurv = 1.0 - abs(dot(n, v));
                    float3 edgeCaustic = float3(0.6, 0.62, 0.7) * pow(edgeCurv, 3.8) * pow(innerGlow, 1.4);
                    
                    col = baseObsidian * ao + surfaceGlint + coreTrans + edgeCaustic;
                }
            }
            
            // Atmospheric volumetric center glow
            col += float3(0.04, 0.042, 0.048) * exp(-distCenter * 2.5);
            
            totalColor += col;
        }
    }
    
    totalColor /= float(aa * aa);
    
    // ACES tone mapping
    totalColor = (totalColor * (2.51 * totalColor + 0.03)) / (totalColor * (2.43 * totalColor + 0.59) + 0.14);
    totalColor = clamp(totalColor, 0.0, 1.0);
    totalColor = pow(totalColor, float3(1.0 / 2.2));
    
    outTexture.write(float4(totalColor, 1.0), gid);
}
"""

guard let library = try? device.makeLibrary(source: metalSource, options: nil),
      let kernelFunction = library.makeFunction(name: "renderKernel4"),
      let pipelineState = try? device.makeComputePipelineState(function: kernelFunction),
      let commandQueue = device.makeCommandQueue() else { fatalError() }

let textureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
textureDesc.usage = [.shaderWrite, .shaderRead]
guard let texture = device.makeTexture(descriptor: textureDesc) else { fatalError() }

guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeComputeCommandEncoder() else { fatalError() }

encoder.setComputePipelineState(pipelineState)
encoder.setTexture(texture, index: 0)

let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
let threadgroupCount = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
encoder.endEncoding()

commandBuffer.commit()
commandBuffer.waitUntilCompleted()

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
), let cgImage = context.makeImage() else { fatalError() }

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
if let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) {
    let outPath = "Resources/Mascot/morph_mascot_4_prism.jpg"
    try? jpegData.write(to: URL(fileURLWithPath: outPath))
    print("Render 4 Success: \(outPath), bytes: \(jpegData.count)")
}
