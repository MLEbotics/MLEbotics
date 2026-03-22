# Troubleshooting Guide

## Backend Server Issues

### "ModuleNotFoundError: No module named 'anthropic'" or other missing modules
**Symptoms:** Get import errors when starting the server

**Solution:**
```powershell
cd backend
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Then start the server again:
```powershell
python app.py
```

---

### "ANTHROPIC_API_KEY not found in environment variables"
**Symptoms:** Server crashes on startup with this error

**Solutions:**
1. Create a `.env` file in the `backend/` folder:
   ```
   ANTHROPIC_API_KEY=sk-ant-xxx...
   ```

2. If `.env` exists, verify your API key is valid:
   - Go to https://console.anthropic.com/account/keys
   - Copy your actual API key
   - Paste it in `.env` replacing the placeholder

3. Make sure `.env` is in the right location: `backend/.env`

---

### "config/user_data.json not found"
**Symptoms:** Server crashes with this error

**Solution:** Create the file if it doesn't exist. The file should be at `config/user_data.json`:
```json
{
  "name": "Your Name",
  "email": "your.email@gmail.com",
  "phone": "555-123-4567",
  "address": "123 Main Street",
  "city": "Your City",
  "country": "Your Country"
}
```

---

### "Address already in use" or "Port 5000 already in use"
**Symptoms:** Error when starting the server

**Solutions:**
1. Another application is using port 5000. Find and kill it:
   ```powershell
   netstat -ano | findstr :5000
   # Note the PID, then:
   taskkill /PID <PID> /F
   ```

2. Or change the port in `backend/app.py` (last line):
   ```python
   app.run(debug=True, port=8000)  # Changed from 5000
   ```
   Then update `extension/popup.js`:
   ```javascript
   const BACKEND_URL = 'http://localhost:8000';
   ```

---

### Server starts but returns errors
**Diagnostic steps:**
1. Test the health endpoint:
   ```powershell
   curl http://localhost:5000/health
   ```
   Should return: `{"status":"ok","service":"AutoFormFiller Backend"}`

2. Check Flask debug output for detailed error messages

3. If you see "API request failed", the API key is likely invalid

---

## Extension Issues

### "Backend server not running"
**Symptoms:** Error when clicking "Fill Form" button

**Solutions:**
1. Start the Flask backend server (see Backend Server Issues)
2. Verify it's running at `http://localhost:5000/health`
3. Check that the server console shows it's listening on port 5000

---

### Extension doesn't appear in the browser
**Symptoms:** No extension icon in toolbar, even though you loaded it

**Solutions:**
1. Go to `chrome://extensions/` in your address bar
2. Verify the extension is listed and **enabled** (toggle should be ON)
3. If not there:
   - Click "Load unpacked"
   - Navigate to the `extension/` folder of this project
   - Click "Select Folder"

4. If still not visible, try:
   - Refresh the extensions page (F5 on `chrome://extensions/`)
   - Restart the browser

---

### "Content script not loaded. Please refresh the page"
**Symptoms:** Form filling fails with this error message

**Causes:** The content script isn't injected on the page yet

**Solutions:**
1. Refresh the webpage (F5)
2. Wait 2 seconds, then try again
3. This is common on single-page applications (React, Vue, etc.)

---

### "No form fields found on this page"
**Symptoms:** Error when used on a specific website

**Possible causes:**
- The website uses a custom form framework
- Form elements are hidden or dynamically generated
- Form elements don't have proper labels/names

**Solutions:**
1. Try a different form on the same website
2. Refresh the page and try again
3. The extension works best with standard HTML forms

---

### Button click does nothing / no response
**Symptoms:** Click "Fill Form" but nothing happens

**Solutions:**
1. Open browser console (F12) and check for errors
2. Verify the backend is running:
   - Go to `http://localhost:5000/health` in browser
   - Should show `{"status":"ok",...}`
3. Check if there are network errors:
   - Open F12 > Network tab
   - Click "Fill Form" button
   - Look for failed requests

---

## API Issues

### "Invalid response format from AI"
**Symptoms:** Backend returns this error when processing a form

**Cause:** Claude's response wasn't valid JSON

**Solution:**
This is rare but can happen if:
1. The prompt is malformed (check `app.py`)
2. Claude returned something unexpected

Check the Flask server logs to see Claude's actual response.

---

### API key appears valid but requests fail
**Solutions:**
1. Verify your API key hasn't been revoked:
   - Go to https://console.anthropic.com/account/keys
   - Check if the key is listed and active

2. Check your API quota/credits:
   - Visit https://console.anthropic.com/account/billing/overview
   - Ensure you have available balance

3. Test API key directly:
   ```powershell
   cd backend
   .\venv\Scripts\Activate.ps1
   python
   ```
   Then in Python:
   ```python
   from anthropic import Anthropic
   client = Anthropic(api_key="your_key_here")
   response = client.messages.create(
       model="claude-3-5-sonnet-20241022",
       max_tokens=10,
       messages=[{"role": "user", "content": "hi"}]
   )
   print(response.content[0].text)
   ```

---

## Configuration Issues

### Changing the backend URL or port
1. Update Flask in `backend/app.py` (last line)
2. Update extension in `extension/popup.js` (line 2 after `// Configuration`)
3. Make sure to update BOTH files
4. Reload the extension: Go to `chrome://extensions/`, find the extension, click the refresh icon

---

### Using the extension on a different machine
1. Copy the entire project folder to the other machine
2. Run `setup.ps1` on that machine
3. Add API key to `.env` on that machine
4. Start the backend server
5. Load the extension in the browser

**Note:** The backend must be running on every machine you use the extension.

---

## Performance Issues

### Slow form filling
**Cause:** Claude API latency or network issues

**Solution:**
Wait longer for the response. The status message shows what's happening.

### High API costs
**Solutions:**
1. Only use on forms you'll actually submit
2. The smart field matching reduces unnecessary API calls
3. You can monitor usage at https://console.anthropic.com/account/usage

---

## Getting Help

If you encounter an issue not listed here:

1. **Check the logs:**
   - Flask server console output
   - Browser console (F12)
   - Browser extension errors (chrome://extensions/ → Details → Errors)

2. **Try these general fixes:**
   - Restart the backend server
   - Refresh the webpage
   - Reload the extension (chrome://extensions/)
   - Restart the browser

3. **Verify your setup:**
   - Run `setup.ps1` again `
   - Verify `.env` has your real API key
   - Verify `user_data.json` has your info

4. **Document what you tried:**
   - Error messages
   - When it happens (always? specific sites?)
   - Steps to reproduce

---

Last updated: March 2026
