# How to Export Store Assets as PNGs

All HTML files in this folder are pre-designed at exact Chrome Web Store dimensions.
Open them in Microsoft Edge and capture PNGs using the steps below.

---

## For each file:

### 1. promo-tile-440x280.html → PNG (440×280)
### 2. promo-tile-920x680.html → PNG (920×680)
### 3. promo-tile-1400x560.html → PNG (1400×560)
### 4. screenshot-1280x800.html → PNG (1280×800)

---

## Capture Steps (Microsoft Edge)

1. Open the HTML file in Edge (drag & drop, or File → Open)
2. Press **F12** to open DevTools
3. Click the **Toggle device toolbar** icon (phone/tablet icon, top left of DevTools), or press **Ctrl+Shift+M**
4. Click **"Responsive"** dropdown at the top → select **"Edit..."** at the bottom → **"Add custom device"**
5. Enter the exact dimensions (e.g., 440 width, 280 height), DPR = 1, click Save
6. Select your custom device from the dropdown
7. Press **Ctrl+Shift+P** → type **"Capture screenshot"** → press Enter
8. Edge saves the PNG automatically to your Downloads folder
9. Rename it to match the asset (e.g., `promo-440x280.png`)

---

## Alternative: Snipping Tool (Windows)
1. Open the HTML in Edge at the correct device emulation size (step 1-6 above)
2. Press **Win+Shift+S** → drag to capture exactly the browser viewport area
3. Paste into Paint or Snipping Tool → save as PNG at the correct size

---

## Final Assets to Upload to Chrome Web Store:

| File | Dimensions | Upload Field in Developer Dashboard |
|---|---|---|
| `promo-440x280.png` | 440×280 | Promotional tile (Small) |
| `promo-920x680.png` | 920×680 | Promotional tile (Large) |
| `promo-1400x560.png` | 1400×560 | Marquee promotional tile |
| `screenshot-1280x800.png` | 1280×800 | Screenshots (at least 1 required) |
