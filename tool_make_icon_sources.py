"""Build padded, square icon source images from the wide AZIMUTH logo.

The full logo is landscape (640x264); a square app icon needs the compact
"truck cab" mark, centred with generous padding, so it does not look cramped.

We isolate the truck cab + front wheel by taking the single largest connected
component of the logo (which is exactly that cluster) so no stray fragments of
the trailer / mudguard leak in.

Outputs:
  assets/branding/app_icon.png            1024 white bg, truck ~60% (legacy + iOS)
  assets/branding/app_icon_foreground.png 1024 transparent, truck ~48% (adaptive)
"""
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "assets/branding/azimuth_logo.png"

logo = Image.open(SRC).convert("RGBA")
arr = np.array(logo)
mask = arr[:, :, 3] > 40

lbl, n = ndimage.label(mask, structure=np.ones((3, 3)))
# Largest connected component = the truck cab + front wheel.
sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n + 1))
truck_id = int(np.argmax(sizes)) + 1

keep = lbl == truck_id
clean = arr.copy()
clean[~keep] = (0, 0, 0, 0)          # drop every other stroke
truck_img = Image.fromarray(clean, "RGBA").crop(
    Image.fromarray((keep * 255).astype("uint8")).getbbox()
)


def build(canvas, frac, white_bg):
    tw, th = truck_img.size
    target = int(round(canvas * frac))
    ratio = target / max(tw, th)
    new = (max(1, round(tw * ratio)), max(1, round(th * ratio)))
    scaled = truck_img.resize(new, Image.LANCZOS)
    bg = (255, 255, 255, 255) if white_bg else (0, 0, 0, 0)
    out = Image.new("RGBA", (canvas, canvas), bg)
    off = ((canvas - new[0]) // 2, (canvas - new[1]) // 2)
    out.alpha_composite(scaled, off)
    return out


build(1024, 0.60, white_bg=True).save("assets/branding/app_icon.png")
build(1024, 0.48, white_bg=False).save("assets/branding/app_icon_foreground.png")
print("truck component id", truck_id, "size", truck_img.size)
