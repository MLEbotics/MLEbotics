# Auto Form Filler - Complete Setup Guide

A browser extension that automatically fills website forms using Claude AI. This project consists of a Chrome/Edge browser extension paired with a Python Flask backend.

## Project Structure
```
├── backend/                 # Python Flask server
│   ├── app.py             # Main server with Claude integration
│   ├── requirements.txt    # Python dependencies
│   ├── .env.example       # Environment variables template
│   └── venv/              # Virtual environment (created during setup)
├── extension/             # Browser extension (Chrome/Edge/Brave)
│   ├── manifest.json      # Extension configuration
│   ├── popup.html         # Extension popup UI
│   ├── popup.js           # Popup logic
│   ├── content.js         # Page interaction script
│   └── background.js      # Background service worker
└── config/
    └── user_data.json     # Your form data (customize this)
```

## System Requirements
- Windows/Mac/Linux
- Python 3.8 or higher
- Chrome, Edge, or Brave browser
- Anthropic API key (free tier available)

## Quick Setup (Recommended)

### 1. Run the Setup Script
Open PowerShell in the `AutoFormFiller` directory and run:
```powershell
.\setup.ps1
```

This will:
- Verify Python installation
- Create a virtual environment
- Install all dependencies
- Set up configuration files

### 2. Add Your API Key
1. Go to [console.anthropic.com/account/keys](https://console.anthropic.com/account/keys)
2. Create a new API key (or copy existing)
3. Open `backend/.env` and replace `your_api_key_here` with your actual key

### 3. Configure Your Data
Edit `config/user_data.json` with your actual information:
```json
{
  "name": "Your Full Name",
  "email": "your.email@gmail.com",
  "phone": "555-123-4567",
  "address": "123 Main Street",
  "city": "Your City",
  "country": "Your Country"
}
```

### 4. Start the Backend Server
```powershell
cd backend
.\venv\Scripts\Activate.ps1
python app.py
```
When successful, you should see:
```
WARNING: This is a development server. Do not use it in production.
Running on http://127.0.0.1:5000
```

**Keep this terminal open** while using the extension.

### 5. Load the Extension in Your Browser

#### Chrome/Edge/Brave:
1. Press **`Ctrl+Shift+M`** (or `Cmd+Shift+M` on Mac) to open Extensions
2. Enable **"Developer mode"** (toggle in top right)
3. Click **"Load unpacked"**
4. Navigate to the `extension/` folder and select it
5. You should see "Auto Form Filler" in your extensions list

## How to Use

1. **Navigate to a form** on any website
2. **Click the "Auto Form Filler" extension icon** in your browser
3. Click the **"Fill Form"** button
4. The extension will analyze form fields and fill matching ones with your data
5. Review and submit the form

## Features

- ✅ Automatic form field detection
- ✅ Intelligent field matching using Claude AI
- ✅ Supports text inputs, text areas, and select dropdowns
- ✅ Works on most websites
- ✅ Real-time status feedback
- ✅ Comprehensive error handling

## Troubleshooting

### "Backend server not running at http://localhost:5000"
**Solution:** 
- Start the Flask server (see Step 4 above)
- Make sure you ran `Activate.ps1` before running `python app.py`
- Verify no other app is using port 5000

### "ANTHROPIC_API_KEY not found"
**Solution:**
- Create `.env` file in `backend/` folder
- Add: `ANTHROPIC_API_KEY=your-key-here`
- Restart the Flask server

### "No form fields found on this page"
**Solutions:**
- The page might not have a standard form
- Refresh the page and try again
- Some websites use custom form implementations

### "Content script not loaded. Please refresh the page and try again"
**Solution:**
- Refresh the webpage (F5)
- Sometimes needed on single-page applications
- Ensure extension is enabled

### "ModuleNotFoundError: No module named 'anthropic'"
**Solution:**
```powershell
cd backend
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Extension doesn't appear in browser
**Solution:**
- Go to `chrome://extensions/` in address bar
- Enable "Developer mode" (top right)
- Verify extension is enabled (toggle ON)
- Try clicking its icon in the toolbar

## Advanced Configuration

### Changing Backend Port
To use a different port than 5000:

1. In `backend/app.py`, change the last line:
```python
app.run(debug=True, port=8000)  # Changed from 5000
```

2. In `extension/popup.js`, update the URL:
```javascript
const BACKEND_URL = 'http://localhost:8000';
```

### Using a Remote Backend
Replace `BACKEND_URL` in `extension/popup.js`:
```javascript
const BACKEND_URL = 'https://your-server.com';
```

Ensure CORS is properly configured in `backend/app.py`.

## API Endpoint Reference

### GET /health
Health check endpoint.
**Response:** `{"status": "ok"}`

### POST /api/fill-form
Main endpoint for form filling.
**Request:**
```json
{
  "fields": [
    {
      "id": "email_input",
      "name": "email",
      "type": "email",
      "label": "email address",
      "placeholder": "Enter your email"
    }
  ]
}
```
**Response:**
```json
{
  "success": true,
  "instructions": [
    {
      "fieldId": "email_input",
      "value": "your.email@gmail.com",
      "reason": "Matched to email field"
    }
  ]
}
```

## Development

### Backend Stack
- Python 3.8+
- Flask 3.0.0
- Anthropic Python SDK 0.25.0
- Flask-CORS 4.0.0

### Extension Stack
- Manifest V3
- Vanilla JavaScript (no frameworks)
- Chrome Web APIs

### Running Backend in Development
```powershell
cd backend
.\venv\Scripts\Activate.ps1
python -m flask run --debug
```

### Debugging the Extension
1. Go to `chrome://extensions/`
2. Find "Auto Form Filler"
3. Click "Details" then "Errors"
4. Or right-click popup and select "Inspect popup" for popup debugging

## Security Notes

⚠️ **Important:**
- Never commit your `.env` file with API keys to version control
- The `.env` file is already in `.gitignore` (if using Git)
- API keys in `user_data.json` are stored locally only
- This is a personal/local tool - don't expose the backend to the internet without authentication

## Common Form Types Supported

The extension works best with:
- Standard HTML forms (input, textarea, select)
- Forms with proper labels
- Forms using standard HTML attributes
- Most modern websites

May have limited success with:
- JavaScript-heavy SPAs (refresh and retry)
- Captcha-protected forms
- Dynamic form builders
- Forms that require specific validation

## Support & Issues

For issues or feature requests, check:
1. Troubleshooting section above
2. Browser console (F12) for error messages
3. Flask server terminal output
4. Anthropic API status page

---

**Version:** 1.0  
**Last Updated:** March 2026

```powershell
cd backend
python app.py
```
Server will run on `http://localhost:5000`

### 5. Load Extension in Chrome/Edge

#### Chrome:
1. Open `chrome://extensions/`
2. Turn on "Developer mode" (top right)
3. Click "Load unpacked"
4. Select the `extension/` folder
5. Extension installed!

#### Edge:
1. Open `edge://extensions/`
2. Turn on "Developer mode" (left sidebar)
3. Click "Load unpacked"
4. Select the `extension/` folder
5. Extension installed!

## How to Use

1. Backend server must be running (`python app.py`)
2. Go to any website with a form
3. Click the extension icon
4. Click "Fill Form"
5. Form fields auto-fill!

## Troubleshooting

**Extension not working?**
- Make sure backend is running on localhost:5000
- Check browser console (F12) for errors
- Reload extension after changes

**Form not filling?**
- Check that form fields have proper labels
- Open browser console to see error messages
- Verify user_data.json has the right information

**API key error?**
- Verify .env file is in `backend/` folder
- Check API key is correct at console.anthropic.com
- Restart Flask server after adding .env
