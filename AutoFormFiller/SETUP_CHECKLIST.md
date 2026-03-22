# Setup Checklist

Use this checklist to track your setup progress and ensure nothing is missed.

## Pre-Setup
- [ ] Python 3.8+ installed on your computer
- [ ] Chrome, Edge, or Brave browser available
- [ ] Internet connection to download packages

## Getting API Key
- [ ] Go to https://console.anthropic.com/account/keys
- [ ] Create account or log in (free tier available)
- [ ] Copy your API key
- [ ] Keep it safe (don't share or commit to git)

## Automatic Setup (Recommended)
- [ ] Open PowerShell in `AutoFormFiller` folder
- [ ] Run `.\setup.ps1`
- [ ] Wait for it to complete
- [ ] All checks pass in the script output

OR: Alternative Setup
- [ ] Open Command Prompt in `AutoFormFiller` folder
- [ ] Run `START.cmd`
- [ ] Follow on-screen instructions

## Manual Setup (If Scripts Don't Work)
- [ ] Navigate to `backend` folder
- [ ] Run `python -m venv venv` (creates virtual environment)
- [ ] Run `.\venv\Scripts\Activate.ps1` (or `venv\Scripts\activate.bat`)
- [ ] Run `pip install -r requirements.txt`

## Configuration
- [ ] Verify `backend\.env.example` exists
- [ ] Create `backend\.env` file (copy from `.env.example`)
- [ ] Add your API key to `backend\.env`
  - [ ] Replace `your_api_key_here` with actual key
  - [ ] Key starts with `sk-ant-`
  - [ ] Save the file

- [ ] Edit `config\user_data.json` with your information
  - [ ] Add your full name
  - [ ] Add your email address
  - [ ] Add your phone number
  - [ ] Add your street address
  - [ ] Add your city
  - [ ] Add your country
  - [ ] Save the file

## File Verification
- [ ] `backend\app.py` exists
- [ ] `backend\requirements.txt` exists
- [ ] `backend\.env` exists and has your API key
- [ ] `config\user_data.json` exists and is valid
- [ ] `extension\manifest.json` exists
- [ ] `extension\popup.html` exists
- [ ] `extension\popup.js` exists
- [ ] `extension\content.js` exists
- [ ] `extension\background.js` exists

## Test Setup (Optional)
- [ ] Run `.\verify.ps1` to check all configuration
- [ ] All checks pass (or only warnings for optional items)

## Start the Backend
- [ ] Open NEW PowerShell window in `AutoFormFiller` folder
- [ ] Navigate to `backend`: `cd backend`
- [ ] Activate environment: `.\venv\Scripts\Activate.ps1`
- [ ] Start server: `python app.py`
- [ ] See "Running on http://127.0.0.1:5000"
- [ ] Keep this window open while using extension

## Load Extension in Browser
- [ ] Open Chrome, Edge, or Brave
- [ ] Press `Ctrl+Shift+M` (opens Extensions page)
- [ ] Enable "Developer mode" toggle (top right)
- [ ] Click "Load unpacked" button
- [ ] Navigate to the `extension` folder
- [ ] Click "Select Folder"
- [ ] See "Auto Form Filler" in extensions list
- [ ] Extension icon appears in toolbar

## Test the Extension
- [ ] Go to a website with a form
- [ ] Click the extension icon in toolbar
- [ ] See popup with "Fill Form" button
- [ ] Click "Fill Form" button
- [ ] See status message change to "Analyzing form..."
- [ ] Form fields auto-fill with your data
- [ ] Status shows "Form filled successfully!"

## Troubleshooting (If Issues Occur)
- [ ] Check browser console (F12) for errors
- [ ] Check Flask server output for error messages
- [ ] Verify API key is correct in `.env`
- [ ] Verify user data is valid JSON in `user_data.json`
- [ ] See TROUBLESHOOTING.md for specific issues

## Advanced Configuration (Optional)
- [ ] Change port number in `backend\app.py` if needed
- [ ] Update extension URL if using remote backend
- [ ] Customize Claude prompt in `app.py`
- [ ] Modify form field extraction in `extension\content.js`

## Verification Checklist
Run this occasionally to ensure everything still works:

### Daily
- [ ] Backend server starts without errors
- [ ] Extension loads in browser
- [ ] Can click "Fill Form" button
- [ ] At least one form field fills correctly

### Weekly
- [ ] Run `.\verify.ps1` to check all files
- [ ] Review any error messages in console
- [ ] Check API usage at console.anthropic.com

### After Any Changes
- [ ] Restart Flask server (`python app.py`)
- [ ] Reload extension (chrome://extensions/)
- [ ] Refresh the webpage
- [ ] Test on a fresh form

## Completion
- [ ] All items above checked
- [ ] Ready to use AutoFormFiller
- [ ] Bookmark TROUBLESHOOTING.md for reference
- [ ] Read DEVELOPMENT.md if planning to modify code

---

**Setup Status:** 
- Start Date: ___________
- Completion Date: ___________
- Issues Encountered: ___________

See QUICKSTART.md for the 5-minute quick start version of this checklist.
