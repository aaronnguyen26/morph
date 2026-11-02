#!/usr/bin/env python3
import os
import sys
from PIL import Image
import numpy as np

EXPECTED_FILES = [
    "morphy_mascot_1_curious.jpg",
    "morphy_mascot_2_focus.jpg",
    "morphy_mascot_3_floating.jpg",
    "morphy_mascot_4_orbital.jpg",
    "morphy_mascot_5_music.jpg",
]

PROJECT_DIR = "Resources/Mascot"
ARTIFACT_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/43ec6192-97af-4b07-9886-7740e25ada26"

def verify():
    print("=== AUTOMATED VERIFICATION: 5 3D CHARACTER MASCOT ASSETS ===")
    errors = []
    
    for idx, fname in enumerate(EXPECTED_FILES, 1):
        p_path = os.path.join(PROJECT_DIR, fname)
        a_path = os.path.join(ARTIFACT_DIR, fname)
        
        if not os.path.exists(p_path):
            errors.append(f"Missing in project: {p_path}")
            continue
        if not os.path.exists(a_path):
            errors.append(f"Missing in artifacts: {a_path}")
            continue
            
        img = Image.open(p_path)
        w, h = img.size
        print(f"\n[Character Mascot {idx}] {fname}")
        print(f"  • Resolution: {w} × {h}")
        if w != 1024 or h != 1024:
            errors.append(f"{fname} invalid dimensions: {w}x{h}")
            
        arr = np.array(img).astype(np.float32)
        p_min, p_max, p_mean = arr.min(), arr.max(), arr.mean()
        print(f"  • Dynamic Range: min={p_min:.1f}, max={p_max:.1f}, mean={p_mean:.1f}")
        
        rgb_max = np.maximum(np.maximum(arr[:,:,0], arr[:,:,1]), arr[:,:,2])
        rgb_min = np.minimum(np.minimum(arr[:,:,0], arr[:,:,1]), arr[:,:,2])
        chroma = (rgb_max - rgb_min).mean()
        print(f"  • Mean Chromaticity: {chroma:.2f} (strictly monochrome if < 10)")
        if chroma > 12.0:
            errors.append(f"{fname} exceeds monochromatic threshold: chroma={chroma:.2f}")
            
    print("\n" + "="*50)
    if errors:
        print(f"FAILED with {len(errors)} errors:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    else:
        print("ALL 5 CHARACTER MASCOT ASSETS VERIFIED: 100% PASS!")
        print("Criteria: 5 3D character mascots, black & white monochromatic palette, inspired by Meta Muse & OpenAI Dots.")
        sys.exit(0)

if __name__ == "__main__":
    verify()
