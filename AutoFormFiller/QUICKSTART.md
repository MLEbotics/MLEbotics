# Quick Start Guide - 5 Minutes to Running

Get AutoFormFiller set up and working in 5 minutes.

## Prerequisites
- Python 3.8+ installed
- Chrome, Edge, or Brave browser
- Anthropic API key (get free at [console.anthropic.com](https://console.anthropic.com/account/keys))

## Step 1: Run the Setup Script (2 minutes)

Open PowerShell in the `AutoFormFiller` folder and run:

```powershell
.\setup.ps1
```

This will automatically:
- ✓ Create Python virtual environment
- ✓ Install dependencies
- ✓ Create configuration files

## Step 2: Add Your API Key (1 minute)

1. Go to: https://console.anthropic.com/account/keys
2. Copy your API key
3. Open `backend\.env` file
4. Replace `your_api_key_here` with your actual key:
   ```
   ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
   ```
5. Save the file

## Step 3: Customize Your Data (1 minute)

Edit `config\user_data.json` with your information:

```json
{
  "name": "Jane Smith",
  "email": "jane@example.com",
  "phone": "555-987-6543",
  "address": "456 Oak Avenue",
  "city": "San Francisco",
  "country": "USA"
}
```

## Step 4: Start the Backend (1 minute)

Open a NEW PowerShell window in the `AutoFormFiller` folder:

```powershell
cd backend
.\venv\Scripts\Activate.ps1
python app.py
```

**Keep this window open.** You should see:
```
Running on http://127.0.0.1:5000
```

## Step 5: Load the Extension in Your Browser

### Chrome/Edge/Brave:
1. Press **Ctrl+Shift+M** (opens Extensions)
2. Enable **Developer mode** (toggle in top right)
3. Click **Load unpacked**
4. Select the `extension` folder in your project
5. Done! You should see "Auto Form Filler" in your extensions

## You're Ready! 🎉

Now:
1. Go to any website with a form
2. Click the **Auto Form Filler** icon in your browser
3. Click **Fill Form**
4. Watch it auto-fill!

## Troubleshooting This Quick Start

| Problem | Solution |
|---------|----------|
| "ModuleNotFoundError" | Run `setup.ps1` again |
| "Port 5000 already in use" | Close other Python processes or change port in `app.py` |
| Backend won't start | Verify `.env` file exists with your API key |
| Extension doesn't appear | Refresh `chrome://extensions/` page |
| "Backend not running" | Make sure Flask server is started in step 4 |
| "No form fields found" | Refresh the webpage and try again |

## Key Files

- **`backend\.env`** — Your API key goes here (required)
- **`config\user_data.json`** — Your personal information
- **`backend\app.py`** — The AI backend
- **`extension\`** — The browser extension

## Next Steps

- See [README.md](README.md) for full documentation
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- See [DEVELOPMENT.md](DEVELOPMENT.md) if you want to modify the code

---

**Done!** The extension is now active and ready to fill forms. 🎊
