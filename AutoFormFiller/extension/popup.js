// Configuration — the deployed Railway backend URL
const BACKEND_URL = 'https://autoformfiller-production-8f77.up.railway.app';

// ── Tab switching ─────────────────────────────────────────────────────────────
const tabFill = document.getElementById('tab-fill');
const tabSettings = document.getElementById('tab-settings');
const tabInfo = document.getElementById('tab-info');
const panelFill = document.getElementById('panel-fill');
const panelSettings = document.getElementById('panel-settings');
const panelInfo = document.getElementById('panel-info');

function switchTab(active) {
  tabFill.classList.toggle('active', active === 'fill');
  tabSettings.classList.toggle('active', active === 'settings');
  tabInfo.classList.toggle('active', active === 'info');
  panelFill.classList.toggle('active', active === 'fill');
  panelSettings.classList.toggle('active', active === 'settings');
  panelInfo.classList.toggle('active', active === 'info');
  if (active === 'settings') loadSettings();
}

tabFill.addEventListener('click', () => switchTab('fill'));
tabSettings.addEventListener('click', () => switchTab('settings'));
tabInfo.addEventListener('click', () => switchTab('info'));

// ── Helpers ───────────────────────────────────────────────────────────────────
function showFillStatus(msg, cls) {
  const el = document.getElementById('fillStatus');
  el.style.display = 'block';
  el.textContent = msg;
  el.className = 'status-box ' + (cls || '');
}

// Get the right API key for the selected model from local storage
async function getApiKeyForModel(model) {
  if (!chrome.storage) return '';
  const keys = await chrome.storage.local.get(['anthropic_key', 'openai_key', 'gemini_key']);
  if (model.startsWith('claude')) return keys.anthropic_key || '';
  if (model.startsWith('gpt')) return keys.openai_key || '';
  if (model.startsWith('gemini')) return keys.gemini_key || '';
  return '';
}

// ── Fill button (auto-detects HTML form vs PDF) ───────────────────────────────
document.getElementById('fillBtn').addEventListener('click', async () => {
  const btn = document.getElementById('fillBtn');
  btn.disabled = true;
  showFillStatus('Detecting page type...', 'info');

  try {
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tabs || tabs.length === 0) throw new Error('No active tab found');
    const tab = tabs[0];
    const rawUrl = tab.url || '';

    // Normalise PDF URLs across Edge and Chrome viewers
    let url = rawUrl;
    const edgePdfMatch = rawUrl.match(/^edge-pdf:\/\/(https?|file)\/(.+)$/i);
    const chromePdfMatch = rawUrl.match(/[?&]file=([^&]+)/i);
    if (edgePdfMatch) {
      url = edgePdfMatch[1].toLowerCase() + '://' + edgePdfMatch[2];
    } else if (chromePdfMatch) {
      url = decodeURIComponent(chromePdfMatch[1]);
    }

    const isPdf = /\.pdf(\?|#|$)/i.test(url)
      || /\/pdf\//i.test(url)
      || /^edge-pdf:/i.test(rawUrl);

    const model = document.getElementById('modelSelect').value;
    const api_key = await getApiKeyForModel(model);

    // Backend health check
    try {
      const health = await fetch(`${BACKEND_URL}/health`);
      if (!health.ok) throw new Error();
    } catch {
      throw new Error(`Backend not running at ${BACKEND_URL}. Please start the Flask server.`);
    }

    if (isPdf) {
      // ── PDF flow ──────────────────────────────────────────────────────────
      showFillStatus('Fetching PDF...', 'info');

      let pdfBytes = null;
      if (!url.startsWith('file://')) {
        try {
          const resp = await fetch(url);
          if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
          const buf = await resp.arrayBuffer();
          const view = new Uint8Array(buf);
          let binary = '';
          const chunk = 8192;
          for (let i = 0; i < view.length; i += chunk) {
            binary += String.fromCharCode(...view.subarray(i, i + chunk));
          }
          pdfBytes = btoa(binary);
        } catch (_) {
          pdfBytes = null;
        }
      }

      showFillStatus('Filling PDF with AI...', 'info');
      const profileKeys = SETTINGS_FIELDS;
      const profile = chrome.storage ? await chrome.storage.local.get(profileKeys) : {};
      const body = pdfBytes ? { pdf_base64: pdfBytes, model, api_key, user_data: profile } : { url, model, api_key, user_data: profile };
      const res = await fetch(`${BACKEND_URL}/api/fill-pdf`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      if (!res.ok) throw new Error(`Backend returned status ${res.status}`);
      const data = await res.json();
      if (!data.success) throw new Error(data.error || 'Unknown error from backend');

      const binStr = atob(data.pdf_base64);
      const bytes = new Uint8Array(binStr.length);
      for (let i = 0; i < binStr.length; i++) bytes[i] = binStr.charCodeAt(i);
      const blob = new Blob([bytes], { type: 'application/pdf' });
      const dlUrl = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      const origName = url.split('/').pop().replace(/\?.*/, '') || 'form.pdf';
      anchor.href = dlUrl;
      anchor.download = origName.replace(/\.pdf$/i, '') + '_filled.pdf';
      anchor.click();
      URL.revokeObjectURL(dlUrl);
      showFillStatus(`Done! Filled ${data.filled_count} field(s) - check your Downloads.`, 'success');

    } else {
      // ── HTML form flow ────────────────────────────────────────────────────
      showFillStatus('Analyzing form...', 'info');

      let response;
      try {
        response = await chrome.tabs.sendMessage(tab.id, { action: 'getFormFields' });
      } catch {
        throw new Error('Content script not loaded. Please refresh the page and try again.');
      }

      if (!response.fields || response.fields.length === 0) {
        showFillStatus('No form fields found on this page', 'error');
        return;
      }

      // Load user profile from local storage to send with request
      const profileKeys = SETTINGS_FIELDS;
      const profile = chrome.storage ? await chrome.storage.local.get(profileKeys) : {};

      const backendResponse = await fetch(`${BACKEND_URL}/api/fill-form`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields: response.fields, model, api_key, user_data: profile })
      });
      if (!backendResponse.ok) throw new Error(`Backend returned status ${backendResponse.status}`);
      const fillData = await backendResponse.json();
      if (!fillData.success) throw new Error(fillData.error || 'Unknown error from backend');

      if (!fillData.instructions || fillData.instructions.length === 0) {
        showFillStatus('No matching fields found for your data', 'error');
        return;
      }

      await chrome.tabs.sendMessage(tab.id, { action: 'fillForm', instructions: fillData.instructions });
      showFillStatus(`Filled ${fillData.instructions.length} field(s) successfully!`, 'success');
    }
  } catch (err) {
    console.error('Fill error:', err);
    showFillStatus('Error: ' + err.message, 'error');
  } finally {
    btn.disabled = false;
  }
});

// ── Settings tab ──────────────────────────────────────────────────────────────
const SETTINGS_FIELDS = [
  'name', 'first_name', 'last_name', 'email', 'phone',
  'address', 'city', 'state', 'zip', 'country',
  'company', 'job_title', 'website',
  'date_of_birth', 'gender'
];

function showSettingsStatus(msg, cls) {
  const el = document.getElementById('settingsStatus');
  el.style.display = 'block';
  el.textContent = msg;
  el.className = 'status-box ' + (cls || '');
}

async function loadSettings() {
  showSettingsStatus('Loading...', 'info');
  try {
    // All data stored locally — never on the server
    if (chrome.storage) {
      const keys = SETTINGS_FIELDS.concat(['anthropic_key', 'openai_key', 'gemini_key']);
      const stored = await chrome.storage.local.get(keys);
      SETTINGS_FIELDS.forEach(key => {
        const el = document.getElementById(`s-${key}`);
        if (el && stored[key] !== undefined) el.value = stored[key];
      });
      if (stored.anthropic_key) document.getElementById('s-anthropic_key').value = stored.anthropic_key;
      if (stored.openai_key) document.getElementById('s-openai_key').value = stored.openai_key;
      if (stored.gemini_key) document.getElementById('s-gemini_key').value = stored.gemini_key;
    }

    document.getElementById('settingsStatus').style.display = 'none';
  } catch (err) {
    showSettingsStatus('Could not load data: ' + err.message, 'error');
  }
}

document.getElementById('saveBtn').addEventListener('click', async () => {
  const btn = document.getElementById('saveBtn');
  btn.disabled = true;
  showSettingsStatus('Saving...', 'info');

  try {
    // Save everything to local Chrome storage only — nothing goes to the server
    const data = {};
    SETTINGS_FIELDS.forEach(key => {
      const el = document.getElementById(`s-${key}`);
      if (el) data[key] = el.value.trim();
    });
    data.anthropic_key = document.getElementById('s-anthropic_key').value.trim();
    data.openai_key = document.getElementById('s-openai_key').value.trim();
    data.gemini_key = document.getElementById('s-gemini_key').value.trim();

    if (chrome.storage) {
      await chrome.storage.local.set(data);
    }

    showSettingsStatus('Saved!', 'success');
  } catch (err) {
    showSettingsStatus('Error: ' + err.message, 'error');
  } finally {
    btn.disabled = false;
  }
});
