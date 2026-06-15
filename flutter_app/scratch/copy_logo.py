import os
import shutil

src = r"c:\dukaanZone\flutter_app\logo\ChatGPT Image May 24, 2026, 04_38_37 PM.png"
dst_dir = r"c:\dukaanZone\flutter_app\assets"
dst = os.path.join(dst_dir, "logo.png")

if not os.path.exists(dst_dir):
    os.makedirs(dst_dir)

try:
    shutil.copy2(src, dst)
    print(f"Successfully copied logo from {src} to {dst}")
except Exception as e:
    print(f"Error copying logo: {e}")
