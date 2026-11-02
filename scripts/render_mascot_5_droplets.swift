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

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float mapScene5(float3 p, thread int &matId) {
    float3 pRot = rotateY(rotateX(p, 0.35), 0.52);
    
    // Central Dynamic Island floating squircle pill
    float dPill = sdRoundBox(pRot, float3(0.70, 0.28, 0.28), 0.26);
    
    // Fluid droplets in mid-fusion
    float dDrop1 = sdSphere(pRot - float3(0.82, 0.42, 0.22), 0.30);
    float dDrop2 = sdSphere(pRot - float3(-0.72, -0.36, -0.18), 0.26);
    float dDrop3 = sdSphere(pRot - float3(-0.52, 0.45, 0.14), 0.20);
    float dDrop4 = sdSphere(pRot - float3(0.45, -0.42, 0.18), 0.18);
    
    // Smooth liquid blend with surface tension meniscus
    float dFused = smin(dPill, dDrop1, 0.26);
    dFused = smin(dFused, dDrop2, 0.24);
    dFused = smin(dFused, dDrop3, 0.20);
    dFused = smin(dFused, dDrop4, 0.18);
    
    // Subtle organic surface ripples
    float ripple = sin(pRot.x * 14.0 + pRot.y * 12.0) * cos(pRot.z * 14.0) * 0.008;
    dFused += ripple;
    
    // Satellite zero-gravity floating beads
    float dB1 = sdSphere(p - float3(1.35, 0.95, 0.4), 0.07);
    float dB2 = sdSphere(p - float3(-1.3, -0.85, 0.3), 0.085);
    float dB3 = sdSphere(p - float3(0.15, 1.35, -0.25), 0.055);
    float dB4 = sdSphere(p - float3(-0.85, 1.15, 0.6), 0.045);
    float dB5 = sdSphere(p - float3(1.15, -0.95, -0.4), 0.065);
    float dB6 = sdSphere(p - float3(-1.4, 0.4, -0.35), 0.05);
    float dB7 = sdSphere(p - float3(0.75, 1.25, 0.45), 0.04);
    float dB8 = sdSphere(p - float3(-0.25, -1.35, 0.35), 0.06);
    float dB9 = sdSphere(p - float3(1.45, -0.2, 0.2), 0.04);
    float dB10 = sdSphere(p - float3(-0.5, 1.45, -0.2), 0.035);
    float dBeads = min(min(min(min(min(dB1, dB2), min(dB3, dB4)), min(dB5, dB6)), min(dB7, dB8)), min(dB9, dB10));
    
    if (dBeads < dFused) {
        matId = 2; // Chrome beads
        return dBeads;
    } else {
        matId = 1; // Fused body
        return dFused;
    }
}

float3 calcNormal5(float3 p) {
    int dummy;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        mapScene5(p + e.xyy, dummy) - mapScene5(p - e.xyy, dummy),
        mapScene5(p + e.yxy, dummy) - mapScene5(p - e.yxy, dummy),
        mapScene5(p + e.yyx, dummy) - mapScene5(p - e.yyx, dummy)
    ));
}

float calcAO5(float3 p, float3 n) {
    float occ = 0.0;
    float sca = 1.0;
    int dummy;
    for (int i = 0; i < 6; i++) {
        float h = 0.015 + 0.12 * float(i) / 5.0;
        float d = mapScene5(p + h * n, dummy);
        occ += (h - d) * sca;
        sca *= 0.82;
    }
    return clamp(1.0 - 2.8 * occ, 0.0, 1.0);
}

// Monochromatic high-contrast luxury studio environment with crisp rim highlights
float3 studioEnv(float3 dir) {
    float3 col = float3(0.008, 0.008, 0.01);
    
    // Top primary softbox
    float top = smoothstep(0.45, 0.95, dir.y) * smoothstep(0.65, 0.0, abs(dir.x));
    col += float3(1.8) * top;
    
    // Razor rim softbox on the left
    float left = smoothstep(0.55, 0.98, -dir.x) * smoothstep(0.6, 0.0, abs(dir.y));
    col += float3(2.2) * left;
    
    // Top-right specular accent
    float tr = smoothstep(0.6, 0.96, dir.x * 0.7 + dir.y * 0.7);
    col += float3(1.6) * tr;
    
    // Bottom subtle bounce
    float bottom = smoothstep(0.5, 0.95, -dir.y) * 0.15;
    col += float3(bottom);
    
    return col;
}

kernel void renderKernel5(
    texture2d<float, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = outTexture.get_width();
    uint h = outTexture.get_height();
    if (gid.x >= w || gid.y >= h) return;
    
    float3 totalColor = float3(0.0);
    const int aa = 2; // 2x2 MSAA
    
    for (int sx = 0; sx < aa; sx++) {
        for (int sy = 0; sy < aa; sy++) {
            float2 offset = float2(float(sx) / float(aa), float(sy) / float(aa));
            float2 uv = (float2(gid) + offset - float2(w, h) * 0.5) / float(h);
            uv.y = -uv.y;
            
            float3 ro = float3(0.0, 0.0, 5.8);
            float3 rd = normalize(float3(uv * 1.25, -2.0));
            
            float t = 0.0;
            int matId = 0;
            bool hit = false;
            
            for (int i = 0; i < 180; i++) {
                float3 p = ro + rd * t;
                float d = mapScene5(p, matId);
                if (d < 0.0006) {
                    hit = true;
                    break;
                }
                t += d * 0.68;
                if (t > 14.0) break;
            }
            
            // Clean seamless dark studio background
            float distCenter = length(uv);
            float vignette = 1.0 - 0.78 * distCenter * distCenter;
            float3 col = float3(0.006, 0.006, 0.008) * vignette;
            
            if (hit) {
                float3 p = ro + rd * t;
                float3 n = calcNormal5(p);
                float3 v = -rd;
                float ao = calcAO5(p, n);
                
                // Studio lighting
                float3 keyDir = normalize(float3(3.5, 5.5, 4.0));
                float3 hKey = normalize(keyDir + v);
                float specSharp = pow(max(dot(n, hKey), 0.0), 90.0);
                float specSoft = pow(max(dot(n, hKey), 0.0), 16.0) * 0.3;
                
                // Fresnel reflection
                float fresnel = 0.04 + 0.96 * pow(clamp(1.0 - max(dot(n, v), 0.0), 0.0, 1.0), 4.5);
                float rim = pow(clamp(1.0 - dot(n, v), 0.0, 1.0), 3.2);
                
                // Raytraced reflection of studio environment
                float3 refl = reflect(rd, n);
                float3 envCol = studioEnv(refl);
                
                // Rotation coordinate for material transition
                float3 pRot = rotateY(rotateX(p, 0.35), 0.52);
                // Dynamic diagonal transition: top-left is gloss obsidian black, bottom-right is mirror chrome
                float splitFactor = smoothstep(-0.35, 0.35, pRot.x * 0.8 + pRot.y * 0.7);
                
                if (matId == 2) {
                    // Chrome floating beads
                    col = envCol * 0.95 + float3(1.0) * (specSharp * 2.2 + rim * 2.0 + fresnel * 0.9);
                } else {
                    // Liquid fused body
                    // Chrome side: pure mirror reflections + razor highlights
                    float3 chromeCol = envCol * 0.92 + float3(1.0) * (specSharp * 2.0 + specSoft + rim * 1.8 + fresnel * 0.85);
                    
                    // Obsidian side: deep midnight black body + sharp specular sheen + fresnel rim
                    float3 obsidianBase = float3(0.012, 0.012, 0.016) * ao;
                    float3 obsidianCol = obsidianBase + envCol * fresnel * 0.75 + float3(1.0) * (specSharp * 1.5 + rim * 1.6);
                    
                    col = mix(obsidianCol, chromeCol, splitFactor);
                }
            } else {
                // Ground reflection & contact shadow
                float groundY = -1.8;
                if (rd.y < 0.0) {
                    float gt = (groundY - ro.y) / rd.y;
                    if (gt > 0.0 && gt < 18.0) {
                        float3 gp = ro + rd * gt;
                        float distFloor = length(gp.xz);
                        float floorGlow = exp(-distFloor * 0.55) * 0.05;
                        float shadow = 1.0 - exp(-distFloor * 1.3) * 0.65;
                        col += float3(floorGlow * shadow);
                    }
                }
            }
            
            // Subtle ambient aura around center
            col += float3(0.025, 0.026, 0.030) * exp(-distCenter * 2.4);
            
            totalColor += col;
        }
    }
    
    totalColor /= float(aa * aa);
    
    // Filmic tone mapping
    totalColor = (totalColor * (2.51 * totalColor + 0.03)) / (totalColor * (2.43 * totalColor + 0.59) + 0.14);
    totalColor = clamp(totalColor, 0.0, 1.0);
    totalColor = pow(totalColor, float3(1.0 / 2.2));
    
    outTexture.write(float4(totalColor, 1.0), gid);
}
"""

guard let library = try? device.makeLibrary(source: metalSource, options: nil),
      let kernelFunction = library.makeFunction(name: "renderKernel5"),
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
    let outPath = "Resources/Mascot/morph_mascot_5_droplets.jpg"
    try? jpegData.write(to: URL(fileURLWithPath: outPath))
    print("Render 5 Success: \(outPath), bytes: \(jpegData.count)")
}
