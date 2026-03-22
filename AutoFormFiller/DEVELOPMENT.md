# Development Guide

For developers who want to understand, extend, or modify the AutoFormFiller project.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     User's Browser                          │
├──────────────────────┬──────────────────────────────────────┤
│  Extension (MV3)     │     Visited Website                  │
├──────────────────────┼──────────────────────────────────────┤
│ popup.js             │ Form with input fields               │
│    ↓                 │                                      │
│ content.js ←────────→ Extracts form fields                  │
│ (injected)           │                                      │
└──────────────────────┴──────────────────────────────────────┘
         ↑ (HTTP POST)
         ↓ (JSON Response)
┌─────────────────────────────────────────────────────────────┐
│              Flask Backend (Python)                         │
├─────────────────────────────────────────────────────────────┤
│  app.py                                                     │
│  ├─ Loads user_data.json                                   │
│  ├─ Receives form fields                                   │
│  ├─ Creates Claude prompt                                  │
│  ├─ Calls Anthropic API                                    │
│  ├─ Parses JSON response                                   │
│  └─ Returns fill instructions                              │
└─────────────────────────────────────────────────────────────┘
         ↑ (HTTP)
         ↓ (JSON)
┌─────────────────────────────────────────────────────────────┐
│              Anthropic API (Claude)                         │
├─────────────────────────────────────────────────────────────┤
│  model: claude-3-5-sonnet-20241022                          │
│  ├─ Analyzes form fields and labels                        │
│  ├─ Matches user data to fields                            │
│  └─ Returns fill instructions                              │
└─────────────────────────────────────────────────────────────┘
```

## Code Organization

### Backend Structure

```
backend/
├── app.py              # Main Flask application
│   ├── Environment loading
│   ├── Route handlers:
│   │   ├─ POST /api/fill-form    (main endpoint)
│   │   └─ GET /health            (health check)
│   └── Helper functions:
│       └─ load_user_data()
│
├── requirements.txt    # Python dependencies
│
└── .env               # Environment variables (not in git)
    └── ANTHROPIC_API_KEY=...
```

### Extension Structure

```
extension/
├── manifest.json      # Extension metadata & permissions
│
├── popup.html         # UI shown when extension button clicked
│   └── Styling for the popup
│
├── popup.js           # Popup behavior
│   └── Click handler for "Fill Form" button
│
├── content.js         # Injected into web pages
│   ├── extractFormFields()
│   └── fillFormFields()
│
└── background.js      # Service worker (mostly empty)
```

### Config Structure

```
config/
└── user_data.json     # User's personal data
```

## Key Functions

### Backend: `load_user_data()`
Loads the JSON file containing user information.
- **Input:** None
- **Output:** Dictionary with keys like "name", "email", etc.
- **Errors:** Throws if file not found or invalid JSON

### Backend: `fill_form()` (Route Handler)
Main API endpoint that processes form fields.
- **Input:** POST request with JSON: `{fields: [{id, name, type, label, placeholder}, ...]}`
- **Process:**
  1. Load user data
  2. Create Claude prompt
  3. Call Anthropic API
  4. Parse JSON response
  5. Return fill instructions
- **Output:** `{success: true, instructions: [{fieldId, value, reason}, ...]}`

### Extension: `extractFormFields()`
Scans the page and finds fillable form fields.
- **Input:** None (reads from DOM)
- **Process:**
  1. Get all input, textarea, select elements
  2. Filter hidden elements
  3. Find labels (from label elements, placeholders, aria-label, name)
  4. Build field object with metadata
- **Output:** Array of field objects

### Extension: `fillFormFields()`
Fills form fields with provided values.
- **Input:** Array of `{fieldId, value, reason}`
- **Process:**
  1. Find each field in DOM by ID or name
  2. Set the value
  3. Dispatch change/input/blur events
- **Output:** None (modifies DOM)

## Data Flow

### Basic Flow

1. User clicks "Fill Form" button in extension popup
2. `popup.js` sends message to `content.js`: `{action: 'getFormFields'}`
3. `content.js` extracts all form fields from the page
4. `popup.js` receives field data and POST to Flask: `/api/fill-form`
5. `app.py` loads user data and sends to Claude with a prompt
6. Claude analyzes fields and returns JSON with fill instructions
7. Flask returns instructions to extension
8. `popup.js` sends message to `content.js`: `{action: 'fillForm', instructions: [...]}`
9. `content.js` fills the fields in the DOM
10. User sees fields filled, can review and submit

### With Error Handling

- Every step includes try/catch blocks
- Health check calls `/health` before main API call
- Detailed error messages shown to user
- Server logs all activities for debugging

## Extending the Project

### Add new user data fields

1. Edit `config/user_data.json`:
```json
{
  "name": "...",
  "email": "...",
  "company": "Acme Corp"  // NEW
}
```

2. The AI will automatically match new fields
   - No code changes needed!
   - Edit the Claude prompt in `app.py` if needed

### Add a new API endpoint

1. Add the route in `backend/app.py`:
```python
@app.route('/api/my-endpoint', methods=['POST'])
def my_endpoint():
    data = request.json
    # Process data
    return jsonify({'success': True, 'result': ...})
```

2. Call from extension:
```javascript
fetch('http://localhost:5000/api/my-endpoint', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({...})
})
```

### Change the Claude model

Edit the `model` parameter in `app.py`:
```python
response = client.messages.create(
    model="claude-3-5-sonnet-20241022",  # Change this
    max_tokens=1024,
    messages=[...]
)
```

Available models:
- `claude-3-5-sonnet-20241022` (Recommended - fast & accurate)
- `claude-3-opus-20250219` (Most capable, slower, more expensive)
- `claude-3-haiku-20250307` (Fastest, less capable)

### Improve form field extraction

Edit `content.js` → `extractFormFields()`:
- Add more label detection strategies
- Skip different field types
- Add custom field matching logic

### Improve the prompt

Edit `app.py` → `fill_form()` function:
- Change how the prompt is formatted
- Add more context
- Adjust instructions to Claude

Example: require exact field name matches:
```python
prompt = f"""...
IMPORTANT: Only match fields if the label EXACTLY contains the user data key (case-insensitive).
Example: If the label contains "email", use the email field.
..."""
```

## Testing

### Manual Testing

1. Set up the project (run `setup.ps1`)
2. Add your API key to `.env`
3. Start the backend: `python app.py`
4. Load extension in Chrome/Edge
5. Go to a website with a form
6. Click the extension button
7. Watch the console (F12) for debug logs

### Testing Backend Independently

```powershell
# Test health endpoint
curl http://localhost:5000/health

# Test fill-form endpoint
$body = @{fields = @(@{id="email"; label="email"; type="email"})} | ConvertTo-Json
curl -X POST http://localhost:5000/api/fill-form `
  -Headers @{"Content-Type"="application/json"} `
  -Body $body
```

### Testing the Claude API

```python
# In Python REPL
from anthropic import Anthropic
import os

client = Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))
response = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=100,
    messages=[
        {"role": "user", "content": "Test prompt"}
    ]
)
print(response.content[0].text)
```

## Debugging

### JavaScript Console Errors
1. Press F12 in browser
2. Go to Console tab
3. Click "Fill Form" button
4. Look for errors
5. Check Network tab for HTTP requests

### Flask Server Logs
Watch the terminal where `python app.py` is running:
```
[AutoFormFiller] Processing 5 form fields
[AutoFormFiller] Sending request to Claude API
[AutoFormFiller] Successfully parsed 3 fill instructions
```

### Extension Debug Panel
1. Go to `chrome://extensions/`
2. Find "Auto Form Filler"
3. Click "Details"
4. Click "view background page" or "Errors"

### Content Script Issues
Content script logs appear in:
1. Browser console (F12) on the actual webpage
2. Look for messages starting with `[AutoFormFiller]`

## Performance Optimization

### Current Bottlenecks
1. Claude API latency (~1-3 seconds)
   - Can't optimize: API limitation
   - Could cache responses for same forms

2. Form field extraction
   - Currently searches entire DOM
   - Could optimize with more targeted selectors

### Ideas for Improvement
1. Cache form field templates
2. Pre-process field labels
3. Use smaller Claude model for simple forms
4. Batch multiple form fills
5. Add undo/redo functionality

## Common Pitfalls

1. **Forgetting to activate the virtual environment**
   - Always run `.\venv\Scripts\Activate.ps1` first

2. **API key in version control**
   - Use `.env` file (already in `.gitignore`)
   - Never commit your real API key

3. **CORS issues when backend on different domain**
   - Already handled by `CORS(app)` in Flask
   - Adjust if needed for production

4. **Form fields with the same name**
   - Extension matches by ID first, then name
   - Name matching may fill unintended fields
   - Could improve by checking visibility

5. **Single-page apps blocking content script**
   - User may need to refresh page
   - Each page load might need re-injection

## Future Feature Ideas

- [ ] Save multiple profiles (work, personal, family)
- [ ] Encrypt stored user data
- [ ] Auto-detect form type (login, registration, survey)
- [ ] Custom mapping rules (e.g., "SSN" → "social_security_number")
- [ ] Browser sync across devices
- [ ] Export/import user data
- [ ] Form history
- [ ] Undo/redo after filling
- [ ] Mobile browser support
- [ ] Shortcuts for common forms

---

**Last Updated:** March 2026
