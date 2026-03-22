"""
Scrolling screenshot tool — draw a region on screen, captures full scrollable content.

Usage:
    python screenshot.py [output_file.png]

Steps:
    1. Run the script — a dark overlay appears over your whole screen
    2. Drag a rectangle over the scrollable area you want to capture
    3. Script auto-scrolls and stitches everything into one tall image
    4. Press Escape to cancel at any time
"""

import sys
import os
import time
import ctypes
import ctypes.wintypes
import tkinter as tk
import numpy as np
from datetime import datetime

try:
    import pyautogui
    from PIL import Image
except ImportError:
    os.system("pip install pyautogui pillow numpy")
    import pyautogui
    from PIL import Image

# Pixel-accurate screenshots on high-DPI displays
ctypes.windll.shcore.SetProcessDpiAwareness(2)

SCROLL_AMOUNT  = -5     # scroll clicks per step (negative = down)
SCROLL_PAUSE   = 0.35   # seconds between scrolls
MATCH_BAND     = 80     # px strip height used to detect overlap between frames
SAME_THRESHOLD = 8      # mean pixel diff to declare "page end reached"


# ---------------------------------------------------------------------------
# Region selector — fullscreen overlay, user drags a rectangle
# ---------------------------------------------------------------------------

def select_region():
    """Show a dim fullscreen overlay; user drags to select a region.
    Returns (left, top, width, height) or None if cancelled."""

    result = {}

    root = tk.Tk()
    root.attributes("-fullscreen", True)
    root.attributes("-alpha", 0.25)
    root.attributes("-topmost", True)
    root.configure(bg="black")
    root.wm_attributes("-transparentcolor", "")  # no-op, keeps bg dim

    canvas = tk.Canvas(root, cursor="cross", bg="black", highlightthickness=0)
    canvas.pack(fill=tk.BOTH, expand=True)

    tk.Label(
        root,
        text="Drag to select the scrollable area  •  Esc to cancel",
        bg="black", fg="white", font=("Arial", 15, "bold"),
    ).place(relx=0.5, rely=0.04, anchor="center")

    state = {}
    rect_id = [None]

    def on_press(e):
        state["x1"], state["y1"] = e.x, e.y

    def on_drag(e):
        if rect_id[0]:
            canvas.delete(rect_id[0])
        rect_id[0] = canvas.create_rectangle(
            state["x1"], state["y1"], e.x, e.y,
            outline="cyan", width=2, fill="cyan", stipple="gray25",
        )

    def on_release(e):
        state["x2"], state["y2"] = e.x, e.y
        root.destroy()

    canvas.bind("<ButtonPress-1>", on_press)
    canvas.bind("<B1-Motion>", on_drag)
    canvas.bind("<ButtonRelease-1>", on_release)
    root.bind("<Escape>", lambda e: root.destroy())

    root.mainloop()

    if not all(k in state for k in ("x1", "y1", "x2", "y2")):
        return None

    x1 = min(state["x1"], state["x2"])
    y1 = min(state["y1"], state["y2"])
    x2 = max(state["x1"], state["x2"])
    y2 = max(state["y1"], state["y2"])

    if x2 - x1 < 10 or y2 - y1 < 10:
        print("Selection too small, try again.")
        return None

    return x1, y1, x2 - x1, y2 - y1  # left, top, width, height


# ---------------------------------------------------------------------------
# Capture helpers
# ---------------------------------------------------------------------------

def grab(left, top, width, height):
    return pyautogui.screenshot(region=(left, top, width, height))


def to_array(img):
    return np.array(img.convert("RGB"), dtype=np.int16)


def images_same(a, b):
    return np.mean(np.abs(a - b)) < SAME_THRESHOLD


def find_overlap(prev_arr, curr_arr):
    """Find how many pixels at the top of curr_arr duplicate the bottom of prev_arr."""
    h = prev_arr.shape[0]
    template = curr_arr[:MATCH_BAND]
    best_score, best_offset = float("inf"), MATCH_BAND

    for y in range(h // 2, h - MATCH_BAND + 1):
        score = np.mean(np.abs(prev_arr[y: y + MATCH_BAND] - template))
        if score < best_score:
            best_score, best_offset = score, h - y

    return best_offset, best_score   # overlap pixels, match quality


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def scrolling_screenshot(output_path: str):
    region = select_region()
    if not region:
        print("Cancelled.")
        return

    left, top, width, height = region
    print(f"Region: ({left}, {top})  {width}×{height} px")
    print("Scrolling to top and capturing...")

    cx, cy = left + width // 2, top + height // 2
    pyautogui.click(cx, cy)
    time.sleep(0.2)
    pyautogui.hotkey("ctrl", "Home")
    time.sleep(0.6)

    frames, arrays, same_count = [], [], 0

    while True:
        frame = grab(left, top, width, height)
        arr = to_array(frame)

        if arrays and images_same(arrays[-1], arr):
            same_count += 1
            if same_count >= 2:
                print(f"End of content — {len(frames)} frames captured.")
                break
        else:
            same_count = 0
            frames.append(frame)
            arrays.append(arr)

        pyautogui.scroll(SCROLL_AMOUNT, x=cx, y=cy)
        time.sleep(SCROLL_PAUSE)

    # Single frame — nothing to stitch
    if len(frames) == 1:
        frames[0].save(output_path)
        print(f"Saved → {os.path.abspath(output_path)}")
        return

    # Pixel-accurate stitch
    print("Stitching frames...")
    offsets = []
    for i in range(1, len(frames)):
        overlap_px, score = find_overlap(arrays[i - 1], arrays[i])
        added = max(1, min(height - overlap_px, height))
        offsets.append(added)

    result = Image.new("RGB", (width, height + sum(offsets)))
    result.paste(frames[0], (0, 0))
    y = 0
    for i, added in enumerate(offsets):
        y += added
        result.paste(frames[i + 1], (0, y))

    result = result.crop((0, 0, width, y + height))
    result.save(output_path)
    print(f"Done!  {os.path.getsize(output_path) // 1024} KB → {os.path.abspath(output_path)}")


if __name__ == "__main__":
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    output = sys.argv[1] if len(sys.argv) >= 2 else f"screenshot_{timestamp}.png"
    scrolling_screenshot(output)

