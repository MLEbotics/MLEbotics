import json
import os
import re
import base64
import io
import logging
import threading
from datetime import date
import requests as http_requests
from flask import Flask, request, jsonify, render_template, send_file, make_response
from flask_cors import CORS
from anthropic import Anthropic
from openai import OpenAI
from dotenv import load_dotenv
from pypdf import PdfReader, PdfWriter

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.template_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'pdf_filler', 'templates')
CORS(app)

# ── Server-level API keys (only GEMINI_API_KEY is required for public free tier)
_GEMINI_KEY   = os.getenv('GEMINI_API_KEY', '')
_CLAUDE_KEY   = os.getenv('ANTHROPIC_API_KEY', '')
_OPENAI_KEY   = os.getenv('OPENAI_API_KEY', '')

if _GEMINI_KEY:
    logger.info("Gemini free-tier available")
else:
    logger.warning("GEMINI_API_KEY not set — free tier unavailable")

if _CLAUDE_KEY:
    logger.info("Server-level Anthropic key loaded")
if _OPENAI_KEY:
    logger.info("Server-level OpenAI key loaded")

# ── Allowed model lists ───────────────────────────────────────────────────────
ALLOWED_GEMINI_MODELS = {'gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash-lite'}
ALLOWED_CLAUDE_MODELS = {
    'claude-sonnet-4-6', 'claude-opus-4-6',
    'claude-sonnet-4-20250514', 'claude-opus-4-20250514',
    'claude-haiku-4-5-20251001'
}
ALLOWED_GPT_MODELS = {'gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'}
FREE_TIER_MODEL   = 'gemini-1.5-flash'

# ── Free-tier rate limiter (in-memory, resets daily per IP) ──────────────────
FREE_TIER_DAILY_LIMIT = 10
_rate_counts: dict = {}
_rate_lock = threading.Lock()

def check_free_rate_limit(ip: str):
    today = str(date.today())
    with _rate_lock:
        day_map = _rate_counts.setdefault(ip, {})
        for d in list(day_map):
            if d != today:
                del day_map[d]
        if day_map.get(today, 0) >= FREE_TIER_DAILY_LIMIT:
            raise ValueError(
                f'Free tier limit reached ({FREE_TIER_DAILY_LIMIT} fills/day). '
                'Add your own API key in Settings for unlimited use.'
            )
        day_map[today] = day_map.get(today, 0) + 1

# ── AI routing helper ─────────────────────────────────────────────────────────
def call_ai_model(prompt: str, model: str, provided_key: str = '', client_ip: str = '') -> str:
    """Route prompt to the correct AI provider. Returns the response text."""
    if model in ALLOWED_GEMINI_MODELS:
        import google.generativeai as genai
        key = provided_key or _GEMINI_KEY
        if not key:
            raise ValueError('No Gemini API key available. Add your own in Settings.')
        if not provided_key:
            check_free_rate_limit(client_ip or '0.0.0.0')
        genai.configure(api_key=key)
        gm = genai.GenerativeModel(model)
        resp = gm.generate_content(prompt)
        return resp.text

    elif model in ALLOWED_GPT_MODELS:
        key = provided_key or _OPENAI_KEY
        if not key:
            raise ValueError('No OpenAI API key. Add yours in Settings.')
        oai = OpenAI(api_key=key)
        resp = oai.chat.completions.create(
            model=model, max_tokens=1024,
            messages=[{'role': 'user', 'content': prompt}]
        )
        return resp.choices[0].message.content

    else:
        # Claude (default)
        actual = model if model in ALLOWED_CLAUDE_MODELS else 'claude-sonnet-4-6'
        key = provided_key or _CLAUDE_KEY
        if not key:
            raise ValueError('No Anthropic API key. Add yours in Settings.')
        anth = Anthropic(api_key=key)
        resp = anth.messages.create(
            model=actual, max_tokens=1024,
            messages=[{'role': 'user', 'content': prompt}]
        )
        return resp.content[0].text

# ── User data helpers ─────────────────────────────────────────────────────────
def load_user_data():
    config_path = os.path.join(os.path.dirname(__file__), '..', 'config', 'user_data.json')
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        raise ValueError('config/user_data.json not found.')
    except json.JSONDecodeError:
        raise ValueError('config/user_data.json contains invalid JSON.')

# ── Routes ────────────────────────────────────────────────────────────────────
@app.route('/api/fill-form', methods=['POST'])
def fill_form():
    try:
        data = request.json
        form_fields = data.get('fields', [])
        if not form_fields:
            return jsonify({'success': False, 'error': 'No form fields provided'}), 400

        user_data = data.get('user_data')
        if not user_data or not isinstance(user_data, dict) or not any(user_data.values()):
            return jsonify({'success': False, 'error': 'No user profile data found. Please fill in your details in the Settings tab first.'}), 400

        prompt = f"""You are a form-filling assistant. Look at these form fields and determine which user data should fill them.

Form fields on the page:
{json.dumps(form_fields, indent=2)}

Available user data:
{json.dumps(user_data, indent=2)}

For each form field, output a JSON object with:
- "fieldId": the field id/name exactly as provided
- "value": the value to fill (or null if no matching data)
- "reason": brief explanation (max 50 chars)

Output ONLY a valid JSON array. No other text."""

        model      = data.get('model', FREE_TIER_MODEL)
        api_key    = data.get('api_key', '')
        client_ip  = request.headers.get('X-Forwarded-For', request.remote_addr or '').split(',')[0].strip()

        logger.info(f"fill-form: model={model} free_tier={not bool(api_key)} ip={client_ip}")

        try:
            result_text = call_ai_model(prompt, model, api_key, client_ip)
        except ValueError as e:
            return jsonify({'success': False, 'error': str(e)}), 429 if 'limit' in str(e) else 400

        json_match = re.search(r'\[.*\]', result_text, re.DOTALL)
        if not json_match:
            return jsonify({'success': False, 'error': 'AI returned unexpected response'}), 500

        instructions = json.loads(json_match.group())
        instructions = [i for i in instructions if i.get('value') is not None]
        logger.info(f"Returning {len(instructions)} fill instructions")
        return jsonify({'success': True, 'instructions': instructions})

    except Exception as e:
        logger.error(f"Error in /api/fill-form: {e}", exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/fill-pdf', methods=['POST'])
def fill_pdf():
    try:
        data = request.json
        pdf_url    = data.get('url', '')
        pdf_base64 = data.get('pdf_base64', '')
        model      = data.get('model', FREE_TIER_MODEL)
        api_key    = data.get('api_key', '')
        client_ip  = request.headers.get('X-Forwarded-For', request.remote_addr or '').split(',')[0].strip()

        # Obtain PDF bytes
        if pdf_url:
            if pdf_url.startswith('file:///'):
                local_path = pdf_url[8:].replace('/', os.sep)
                try:
                    with open(local_path, 'rb') as f:
                        pdf_bytes = f.read()
                except OSError as e:
                    return jsonify({'success': False, 'error': f'Could not read local file: {e}'}), 400
            else:
                try:
                    resp = http_requests.get(pdf_url, timeout=15)
                    resp.raise_for_status()
                    pdf_bytes = resp.content
                except Exception as e:
                    return jsonify({'success': False, 'error': f'Could not fetch PDF: {e}'}), 400
        elif pdf_base64:
            try:
                pdf_bytes = base64.b64decode(pdf_base64)
            except Exception:
                return jsonify({'success': False, 'error': 'Invalid base64 PDF data'}), 400
        else:
            return jsonify({'success': False, 'error': 'Provide "url" or "pdf_base64"'}), 400

        reader = PdfReader(io.BytesIO(pdf_bytes))
        raw_fields = reader.get_fields()
        if not raw_fields:
            return jsonify({'success': False, 'error': 'No fillable form fields found in this PDF'}), 400

        fillable_types = {'/Tx', '/Ch'}
        field_list = []
        for name, field in raw_fields.items():
            field_type = str(field.get('/FT', '/Tx'))
            if field_type not in fillable_types:
                continue
            entry = {'id': name, 'label': name, 'type': 'select' if field_type == '/Ch' else 'text'}
            if '/Opt' in field:
                entry['options'] = [str(o) for o in field['/Opt']]
            field_list.append(entry)

        if not field_list:
            return jsonify({'success': False, 'error': 'No text or choice fields found in this PDF'}), 400

        user_data = data.get('user_data')
        if not user_data or not isinstance(user_data, dict) or not any(user_data.values()):
            return jsonify({'success': False, 'error': 'No user profile data found. Please fill in your details in the Settings tab first.'}), 400

        prompt = f"""You are a form-filling assistant. Match PDF fields to user data.

PDF form fields:
{json.dumps(field_list, indent=2)}

Available user data:
{json.dumps(user_data, indent=2)}

Output a JSON array. Each item: {{"fieldId": "...", "value": "..." or null}}
Output ONLY the JSON array. No other text."""

        logger.info(f"fill-pdf: model={model} fields={len(field_list)}")
        try:
            result_text = call_ai_model(prompt, model, api_key, client_ip)
        except ValueError as e:
            return jsonify({'success': False, 'error': str(e)}), 429 if 'limit' in str(e) else 400

        json_match = re.search(r'\[.*\]', result_text, re.DOTALL)
        if not json_match:
            return jsonify({'success': False, 'error': 'AI returned unexpected response'}), 500

        instructions = json.loads(json_match.group())
        fill_map = {i['fieldId']: i['value'] for i in instructions if i.get('value') is not None}

        if not fill_map:
            return jsonify({'success': False, 'error': 'No matching fields found for your data'}), 200

        writer = PdfWriter()
        writer.clone_document_from_reader(reader)
        for page in writer.pages:
            try:
                writer.update_page_form_field_values(page, fill_map)
            except Exception:
                pass

        output_buf = io.BytesIO()
        writer.write(output_buf)
        output_buf.seek(0)
        filled_b64 = base64.b64encode(output_buf.read()).decode('utf-8')
        logger.info(f"PDF filled: {len(fill_map)} fields")
        return jsonify({'success': True, 'pdf_base64': filled_b64, 'filled_count': len(fill_map)})

    except Exception as e:
        logger.error(f"Error in /api/fill-pdf: {e}", exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'service': 'AutoFormFiller Backend'})

@app.errorhandler(404)
def not_found(error):
    return jsonify({'success': False, 'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({'success': False, 'error': 'Internal server error'}), 500

@app.route('/')
def index():
    return render_template('index.html')


@app.route('/fill', methods=['POST'])
def fill_web():
    """Web UI endpoint — accepts multipart form with PDF + user_data_json."""
    try:
        source = request.form.get('source', 'url')
        original_name = 'form.pdf'

        if source == 'url':
            url = request.form.get('url', '').strip()
            if not url:
                return jsonify({'success': False, 'error': 'No URL provided'}), 400
            try:
                resp = http_requests.get(url, timeout=20)
                resp.raise_for_status()
                pdf_bytes = resp.content
                original_name = url.split('/')[-1].split('?')[0] or 'form.pdf'
                if not original_name.lower().endswith('.pdf'):
                    original_name += '.pdf'
            except Exception as e:
                return jsonify({'success': False, 'error': f'Could not fetch PDF: {e}'}), 400
        else:
            file = request.files.get('file')
            if not file or not file.filename:
                return jsonify({'success': False, 'error': 'No file uploaded'}), 400
            if not file.filename.lower().endswith('.pdf'):
                return jsonify({'success': False, 'error': 'Uploaded file must be a PDF'}), 400
            pdf_bytes = file.read()
            original_name = file.filename

        user_data_json = request.form.get('user_data_json', '')
        if user_data_json:
            try:
                user_data = json.loads(user_data_json)
            except json.JSONDecodeError:
                return jsonify({'success': False, 'error': 'Invalid user data JSON'}), 400
        else:
            try:
                user_data = load_user_data()
            except ValueError as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        selected_model = request.form.get('model', FREE_TIER_MODEL)
        api_key = request.form.get('api_key', '')
        client_ip = request.headers.get('X-Forwarded-For', request.remote_addr or '').split(',')[0].strip()

        reader = PdfReader(io.BytesIO(pdf_bytes))
        raw_fields = reader.get_fields()
        if not raw_fields:
            return jsonify({'success': False, 'error': 'No fillable AcroForm fields found in this PDF'}), 400

        fillable_types = {'/Tx', '/Ch'}
        field_list = []
        for name, field in raw_fields.items():
            field_type = str(field.get('/FT', '/Tx'))
            if field_type not in fillable_types:
                continue
            entry = {'id': name, 'label': name, 'type': 'select' if field_type == '/Ch' else 'text'}
            if '/Opt' in field:
                entry['options'] = [str(o) for o in field['/Opt']]
            field_list.append(entry)

        if not field_list:
            return jsonify({'success': False, 'error': 'No text or choice fields found in this PDF'}), 400

        prompt = f"""You are a form-filling assistant. Match PDF fields to user data.

PDF form fields:
{json.dumps(field_list, indent=2)}

Available user data:
{json.dumps(user_data, indent=2)}

Output a JSON array. Each item: {{"fieldId": "...", "value": "..." or null}}
Output ONLY the JSON array. No other text."""

        logger.info(f"fill-web: model={selected_model} fields={len(field_list)}")
        try:
            result_text = call_ai_model(prompt, selected_model, api_key, client_ip)
        except ValueError as e:
            return jsonify({'success': False, 'error': str(e)}), 429 if 'limit' in str(e) else 400

        json_match = re.search(r'\[.*\]', result_text, re.DOTALL)
        if not json_match:
            return jsonify({'success': False, 'error': 'AI returned unexpected response'}), 500

        instructions = json.loads(json_match.group())
        fill_map = {i['fieldId']: i['value'] for i in instructions if i.get('value') is not None}

        if not fill_map:
            return jsonify({'success': False, 'error': 'No matching fields found for your data'}), 200

        writer = PdfWriter()
        writer.clone_document_from_reader(reader)
        for page in writer.pages:
            try:
                writer.update_page_form_field_values(page, fill_map)
            except Exception:
                pass

        out = io.BytesIO()
        writer.write(out)
        out.seek(0)
        download_name = re.sub(r'\.pdf$', '', original_name, flags=re.IGNORECASE) + '_filled.pdf'
        response = make_response(send_file(
            out,
            mimetype='application/pdf',
            as_attachment=True,
            download_name=download_name
        ))
        response.headers['X-Fields-Filled'] = str(len(fill_map))
        response.headers['X-Download-Name'] = download_name
        return response

    except Exception as e:
        logger.error(f"Error in /fill: {e}", exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


if __name__ == '__main__':
    logger.info("Starting AutoFormFiller Backend")
    app.run(debug=True, port=5000)
