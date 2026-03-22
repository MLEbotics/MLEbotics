# Chrome Web Store — Auto Form Filler Submission Package
*Generated: March 15, 2026*

---

## SHORT DESCRIPTION (max 132 chars — paste into "Short description" field)

Fill any web form instantly with AI. Supports free Gemini, Claude & GPT-4. One click. Your data stays on your device.

Character count: 125 ✓

---

## LONG DESCRIPTION (paste into "Detailed description" field)

Auto Form Filler is a smart Chrome extension that fills web forms automatically using AI — no more typing the same name, address, email, and details over and over again.

**How it works:**
Save your profile once (name, email, phone, address, job title, etc.) in the Settings tab. Then visit any website with a form, open the extension, and click Fill Form. The AI reads the form fields, matches your saved data to the right fields, and fills everything in — instantly.

**Supported AI models:**
• Google Gemini (free — no API key needed to get started)
• Anthropic Claude (bring your own API key)
• OpenAI GPT-4 (bring your own API key)

Start completely free using the built-in Gemini tier. No account, no credit card required.

**What it fills:**
• Job applications (name, address, cover letter fields)
• Registration forms (email, phone, DOB, gender)
• Checkout forms (billing and shipping address)
• Government and official portals
• Contact forms and feedback surveys
• Account signup pages
• Any HTML form on any website

**Your privacy is protected:**
• All profile data is stored locally on your device using Chrome's built-in extension storage
• Data is only transmitted when you actively click Fill Form
• Nothing is stored on our servers after a fill request completes
• You can edit or delete your data at any time from the Settings tab
• Full privacy policy at mlebotics.com/privacy-policy.html

**Features:**
• Works on any website — job boards, government sites, online stores, sign-up pages
• Smart AI field matching — understands form context, not just field names
• Free tier included (Gemini) — get started with zero cost
• Multiple AI providers — switch between Gemini, Claude, and GPT-4
• Lightweight — no background tracking, no passive data collection
• Settings tab for full profile management

**Rate limits (free Gemini tier):**
The free Gemini tier allows up to 10 fill requests per day. For unlimited usage, add your own Claude or GPT-4 API key in the Settings tab.

**Setup:**
1. Install the extension
2. Open the popup and go to the Settings tab
3. Fill in your personal details (name, email, address, etc.)
4. Visit any webpage with a form
5. Click Fill Form — done

No backend setup required. The Gemini free tier is handled automatically.

**Links:**
• Homepage: https://mlebotics.com/autoformfiller.html
• Privacy Policy: https://mlebotics.com/privacy-policy.html
• Support: contact@mlebotics.com

By MLEbotics — building tools that save time.

---

## HOST PERMISSIONS JUSTIFICATION
*(Paste this into the "Permission justification" or "Single purpose" box during submission when Google asks about `host_permissions: <all_urls>` and content scripts)*

**Why this extension requires access to all URLs:**

Auto Form Filler is a universal web form-filling tool. Users need to fill forms on an unlimited variety of websites — job application portals, government websites, online store checkout pages, account registration pages, banking forms, survey platforms, and more. It is impossible to enumerate a finite list of URLs in advance because the set of websites that contain forms is effectively unlimited.

The content script injected on each page is passive and minimal. It does not activate automatically, does not collect data, does not monitor browsing behaviour, and does not transmit anything. It only executes when the user explicitly opens the extension popup and clicks the "Fill Form" button. At that point, it reads the visible form fields on the current page and communicates them back to the popup, which then sends them to the AI backend along with the user's saved profile data.

The `host_permissions: <all_urls>` permission is strictly necessary because Chrome requires explicit host permission before a content script can interact with a page's DOM to read form field names and inject fill values. Without access to all URLs, the extension would only work on a pre-defined whitelist of websites, defeating its entire purpose.

The `activeTab` permission is also declared as a secondary mechanism for cases where the user opens the popup on a page not yet covered by the content script.

No passive browsing data, cookies, credentials, or page content unrelated to form fields is ever read or transmitted.

---

## PRIVACY POLICY URL

https://mlebotics.com/privacy-policy.html

---

## CATEGORY

Productivity

---

## TAGS / KEYWORDS

form filler, autofill, AI form, auto fill, form automation, job application, address autofill, GPT form, Gemini form filler, productivity

---

## HOMEPAGE URL (already in manifest)

https://mlebotics.com/autoformfiller.html

---

## STORE ASSETS CHECKLIST

| Asset | Required Size | File | Status |
|---|---|---|---|
| Screenshot 1 | 1280×800 or 640×400 | screenshot-1280x800.html → PNG | Open HTML in browser, set window to 1280×800, screenshot |
| Small promo tile | 440×280 | promo-tile-440x280.html → PNG | Open HTML, screenshot at 440×280 |
| Large promo tile | 920×680 | promo-tile-920x680.html → PNG | Open HTML, screenshot at 920×680 |
| Marquee tile | 1400×560 | promo-tile-1400x560.html → PNG | Open HTML, screenshot at 1400×560 |

### How to capture the HTML tiles as PNGs:
1. Open the HTML file in Microsoft Edge
2. Press F12 to open DevTools
3. Click the device toolbar icon (Ctrl+Shift+M)
4. Set custom dimensions to the exact pixel size
5. Right-click the page → "Screenshot" or use Ctrl+Shift+P → "Capture screenshot"
6. Save as PNG with the matching filename

---

## BACKEND DEPLOYMENT NOTES

The extension popup.js hardcodes: `https://autoformfiller.mlebotics.com`

The backend is configured for Railway deployment:
- Start command: `gunicorn app:app --chdir backend --bind 0.0.0.0:$PORT`
- Health check: `/health`
- Procfile: `web: gunicorn app:app --chdir backend --bind 0.0.0.0:$PORT`

**Before submitting to Chrome Web Store:**
1. Deploy to Railway (or any host) and confirm `https://autoformfiller.mlebotics.com/health` returns `{"status": "ok"}`
2. The Chrome Web Store review team WILL test the extension — the backend must be live and responsive during review

**To deploy on Railway:**
1. Go to railway.app and create a new project
2. Connect the AutoFormFiller GitHub repo
3. Set environment variable `GEMINI_API_KEY` to your Gemini API key
4. Optionally set `ANTHROPIC_API_KEY` and `OPENAI_API_KEY`
5. Set a custom domain: `autoformfiller.mlebotics.com`
6. Point your DNS CNAME to the Railway-provided domain

---

## DEVELOPER DASHBOARD DETAILS

| Field | Value |
|---|---|
| Extension name | Auto Form Filler — AI Powered |
| Version | 1.0.0 |
| Category | Productivity |
| Languages | English |
| Visibility | Public |
| Pricing | Free |
| Privacy policy URL | https://mlebotics.com/privacy-policy.html |
| Support URL | https://mlebotics.com/autoformfiller.html |
| Homepage URL | https://mlebotics.com/autoformfiller.html |
