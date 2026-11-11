#!/usr/bin/env python3
# Kiln Linux: the CPU setting test. darktable and RawTherapee write fresh metadata each run, so
# their files never match; this compares the pixels. Usage: scripts/cpu-level-pixdiff.py BASE OTHER...
"""Pixel difference between JPEGs: share of differing values, and the largest difference (0-255)."""
import sys
import numpy as np
from PIL import Image
base = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.int16)
for other in sys.argv[2:]:
    o = np.asarray(Image.open(other).convert("RGB"), dtype=np.int16)
    if o.shape != base.shape:
        print(other, "different size", o.shape); continue
    d = np.abs(o - base)
    print("%-40s differing %.4f%%  largest %d  mean %.5f" % (other.split("/")[-1], 100 * (d > 0).mean(), d.max(), d.mean()))
