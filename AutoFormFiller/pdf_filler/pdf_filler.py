import json
import os
import re
import io
import logging
import requests as http_requests
from flask import Flask, request, jsonify, render_template, send_file, make_response
from flask_cors import CORS
from anthropic import Anthropic
from dotenv import load_dotenv
from pypdf import PdfReader, PdfWriter

# Load API key from the shared backend .env
dotenv_path = os.path.join(os.path.dirname(__file__), '..', 'backend', '.env')
load_dotenv(dotenv_path)

logging.basicConfig(level=logging.INFO, format='[PDF Filler] %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

api_key = os.getenv('ANTHROPIC_API_KEY')
if not api_key:
    raise ValueError("ANTHROPIC_API_KEY not found. Make sure backend/.env contains it.")

client = Anthropic(api_key=api_key)


def load_user_data():
    config_path = os.path.join(os.path.dirname(__file__), '..', 'config', 'user_data.json')
    with open(config_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    data.pop('_comment', None)
    return data


ALLOWED_MODELS = {
    'claude-sonnet-4-6',
    'claude-opus-4-6',
    'claude-haiku-4-5-20251001',
}
DEFAULT_MODEL = 'claude-sonnet-4-6'


def fill_pdf_bytes(pdf_bytes, model=None):
    """Core logic: read AcroForm fields, ask Claude, fill and return (BytesIO, count)."""
    if model not in ALLOWED_MODELS:
        model = DEFAULT_MODEL
    reader = PdfReader(io.BytesIO(pdf_bytes))
    raw_fields = reader.get_fields()

    if not raw_fields:
        raise ValueError("No fillable AcroForm fields found in this PDF.")

    fillable_types = {'/Tx', '/Ch'}
    field_list = []
    for name, field in raw_fields.items():
        field_type = str(field.get('/FT', '/Tx'))
        if field_type not in fillable_types:
            continue
        entry = {
            'id': name,
            'label': name,
            'type': 'select' if field_type == '/Ch' else 'text'
        }
        if '/Opt' in field:
            entry['options'] = [str(o) for o in field['/Opt']]
        field_list.append(entry)

    if not field_list:
        raise ValueError("No text or choice fields found in this PDF.")

    user_data = load_user_data()
    logger.info(f"Sending {len(field_list)} fields to Claude")

    prompt = f"""You are a form-filling assistant. Look at these PDF form fields and determine which user data should fill them.

PDF form fields:
{json.dumps(field_list, indent=2)}

Available user data:
{json.dumps(user_data, indent=2)}

For each form field output a JSON object with:
- "fieldId": the field name exactly as provided
- "value": the value to fill (or null if no matching data)

Output ONLY a valid JSON array. No other text."""

    response = client.messages.create(
        model=model,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )
    result_text = response.content[0].text
    json_match = re.search(r'\[.*\]', result_text, re.DOTALL)
    if not json_match:
        raise ValueError("AI returned an unexpected response format.")

    instructions = json.loads(json_match.group())
    fill_map = {i['fieldId']: i['value'] for i in instructions if i.get('value') is not None}

    if not fill_map:
        raise ValueError("No matching fields found for your personal data.")

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
    logger.info(f"Filled {len(fill_map)} fields successfully")
    return out, len(fill_map)


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/fill', methods=['POST'])
def fill():
    try:
        source = request.form.get('source', 'url')
        original_name = 'form.pdf'

        if source == 'url':
            url = request.form.get('url', '').strip()
            if not url:
                return jsonify({'success': False, 'error': 'No URL provided'}), 400

            if url.startswith('file:///'):
                # Local file — read directly (app runs on the same machine)
                local_path = url[8:].replace('/', os.sep)
                try:
                    with open(local_path, 'rb') as f:
                        pdf_bytes = f.read()
                    original_name = os.path.basename(local_path)
                except OSError as e:
                    return jsonify({'success': False, 'error': f'Cannot read file: {e}'}), 400
            else:
                try:
                    resp = http_requests.get(url, timeout=20)
                    resp.raise_for_status()
                    pdf_bytes = resp.content
                    original_name = url.split('/')[-1].split('?')[0] or 'form.pdf'
                    if not original_name.lower().endswith('.pdf'):
                        original_name += '.pdf'
                except Exception as e:
                    return jsonify({'success': False, 'error': f'Could not fetch PDF: {e}'}), 400

        else:  # upload
            file = request.files.get('file')
            if not file or not file.filename:
                return jsonify({'success': False, 'error': 'No file uploaded'}), 400
            if not file.filename.lower().endswith('.pdf'):
                return jsonify({'success': False, 'error': 'Uploaded file must be a PDF'}), 400
            pdf_bytes = file.read()
            original_name = file.filename

        selected_model = request.form.get('model', DEFAULT_MODEL)
        output_buf, filled_count = fill_pdf_bytes(pdf_bytes, model=selected_model)
        download_name = re.sub(r'\.pdf$', '', original_name, flags=re.IGNORECASE) + '_filled.pdf'

        response = make_response(send_file(
            output_buf,
            mimetype='application/pdf',
            as_attachment=True,
            download_name=download_name
        ))
        response.headers['X-Fields-Filled'] = str(filled_count)
        response.headers['X-Download-Name'] = download_name
        return response

    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 400
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'service': 'PDF Filler'})


if __name__ == '__main__':
    import socket
    local_ip = socket.gethostbyname(socket.gethostname())
    logger.info(f"Starting PDF Filler")
    logger.info(f"  Local:   http://localhost:5001")
    logger.info(f"  Network: http://{local_ip}:5001")
    app.run(debug=False, host='0.0.0.0', port=5001)
