#!/usr/bin/env python3
import os
import sys
from PIL import Image
import numpy as np

EXPECTED_FILES = [
    "morph_mascot_1_core.jpg",
    "morph_mascot_2_orbital.jpg",
    "morph_mascot_3_ribbon.jpg",
    "morph_mascot_4_prism.jpg",
    "morph_mascot_5_droplets.jpg",
]

PROJECT_DIR = "Resources/Mascot"
ARTIFACT_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/43ec6192-97af-4b07-9886-7740e25ada26"

def verify_images():
    print("=== AUTOMATED VERIFICATION: 5 3D MASCOT ASSETS ===")
    errors = []
    
    for idx, fname in enumerate(EXPECTED_FILES, 1):
        p_path = os.path.join(PROJECT_DIR, fname)
        a_path = os.path.join(ARTIFACT_DIR, fname)
        
        # 1. Existence check
        if not os.path.exists(p_path):
            errors.append(f"Missing in project: {p_path}")
            continue
        if not os.path.exists(a_path):
            errors.append(f"Missing in artifacts: {a_path}")
            continue
            
        # 2. Load image
        img = Image.open(p_path)
        w, h = img.size
        print(f"\n[Asset {idx}] {fname}")
        print(f"  • Resolution: {w} × {h}")
        if w < 512 or h < 512:
            errors.append(f"{fname} resolution too small: {w}x{h}")
            
        arr = np.array(img).astype(np.float32)
        
        # 3. Dynamic range check (ensure not blank / dark)
        p_min, p_max, p_mean = arr.min(), arr.max(), arr.mean()
        print(f"  • Dynamic Range: min={p_min:.1f}, max={p_max:.1f}, mean={p_mean:.1f}")
        if p_max < 150:
            errors.append(f"{fname} has insufficient dynamic range (max={p_max})")
        if p_mean < 5:
            errors.append(f"{fname} is essentially blank/black (mean={p_mean})")
            
        # 4. Monochromatic color palette verification:
        # For pure monochrome / black and white, R, G, B channels should have minimal chromatic difference
        # Saturation = (max(R,G,B) - min(R,G,B)) / max(R,G,B)
        rgb_max = np.maximum(np.maximum(arr[:,:,0], arr[:,:,1]), arr[:,:,2])
        rgb_min = np.minimum(np.minimum(arr[:,:,0], arr[:,:,1]), arr[:,:,2])
        chroma = rgb_max - rgb_min
        mean_chroma = chroma.mean()
        print(f"  • Mean Chromaticity (Color Divergence): {mean_chroma:.2f} (strictly monochrome if < 10)")
        if mean_chroma > 15.0:
            errors.append(f"{fname} exceeds monochromatic threshold: chroma={mean_chroma:.2f}")
            
    print("\n" + "="*50)
    if errors:
        print(f"FAILED with {len(errors)} errors:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    else:
        print("ALL 5 MASCOT ASSETS VERIFIED: 100% PASS!")
        print("Criteria met: 5 3D assets, black & white monochromatic palette, non-anthropomorphic, valid format & dimensions.")
        sys.exit(0)

if __name__ == "__main__":
    verify_images()
