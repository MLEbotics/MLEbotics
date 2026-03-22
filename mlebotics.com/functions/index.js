'use strict';

const functions  = require('firebase-functions');
const admin      = require('firebase-admin');
const Imap       = require('imap');
const nodemailer = require('nodemailer');
const { simpleParser } = require('mailparser');
const { searchIndex } = require('./search-index');
const cors = require('cors')({
  origin: [
    'https://mlebotics.com',
    'http://localhost',
    'http://localhost:4321',
    'http://127.0.0.1',
    'http://127.0.0.1:4321',
  ],
});

admin.initializeApp();
const db = admin.firestore();

// ─── Owner emails that can access real Zoho inbox / send ─────────────────────
const OWNER_EMAILS = new Set([
  'eddie@mlebotics.com',
  'eddie7ch@gmail.com',
]);

// ─── Zoho config — reads from Functions environment (.env in functions/) ──────
function getZohoCfg() {
  return {
    user:     process.env.ZOHO_USER,
    pass:     process.env.ZOHO_APP_PASSWORD,
    imapHost: process.env.ZOHO_IMAP_HOST || 'imap.zohocloud.ca',
    imapPort: parseInt(process.env.ZOHO_IMAP_PORT || '993'),
    smtpHost: process.env.ZOHO_SMTP_HOST || 'smtp.zohocloud.ca',
    smtpPort: parseInt(process.env.ZOHO_SMTP_PORT || '465'),
  };
}

// ─── Auth helper ─────────────────────────────────────────────────────────────
async function verifyToken(req) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Bearer ')) throw Object.assign(new Error('Missing auth token'), { status: 401 });
  return admin.auth().verifyIdToken(h.slice(7));
}

function isOwner(decoded) {
  return OWNER_EMAILS.has(decoded.email);
}

// ─── Sanitise a folder name — only allow word chars, spaces, slashes ─────────
function safeFolder(raw) {
  if (!raw) return 'INBOX';
  const clean = String(raw).replace(/[^a-zA-Z0-9 /._-]/g, '');
  return clean || 'INBOX';
}

// ─── IMAP: list inbox headers ─────────────────────────────────────────────────
function imapFetchHeaders(cfg, folder, limit) {
  return new Promise((resolve, reject) => {
    const imap = new Imap({
      user: cfg.user, password: cfg.pass,
      host: cfg.imapHost, port: cfg.imapPort,
      tls: true, tlsOptions: { rejectUnauthorized: true },
      connTimeout: 15000, authTimeout: 10000,
    });
    imap.once('error', reject);
    imap.once('ready', () => {
      imap.openBox(folder, true, (err, box) => {
        if (err) { imap.end(); return reject(err); }
        const total = box.messages.total;
        if (total === 0) { imap.end(); return resolve([]); }
        const start = Math.max(1, total - limit + 1);
        const f = imap.seq.fetch(`${start}:*`, {
          bodies: 'HEADER.FIELDS (FROM TO SUBJECT DATE)',
          struct: false,
        });
        const rows = [];
        f.on('message', (msg, seqNo) => {
          let raw = ''; let uid;
          msg.on('body', s => s.on('data', c => { raw += c.toString('utf8'); }));
          msg.once('attributes', a => { uid = a.uid; });
          msg.once('end', () => {
            const get = (field) => {
              const re = new RegExp(`^${field}:\\s*(.+)`, 'im');
              const m = raw.match(re);
              return m ? m[1].replace(/\r?\n\s+/g, ' ').trim() : '';
            };
            rows.push({ seqNo, uid, from: get('From'), to: get('To'), subject: get('Subject'), date: get('Date') });
          });
        });
        f.once('error', reject);
        f.once('end', () => { imap.end(); resolve(rows.reverse()); });
      });
    });
    imap.connect();
  });
}

// ─── IMAP: fetch one email body ───────────────────────────────────────────────
function imapFetchBody(cfg, folder, uid) {
  return new Promise((resolve, reject) => {
    const imap = new Imap({
      user: cfg.user, password: cfg.pass,
      host: cfg.imapHost, port: cfg.imapPort,
      tls: true, connTimeout: 15000, authTimeout: 10000,
    });
    imap.once('error', reject);
    imap.once('ready', () => {
      imap.openBox(folder, false, (err) => {
        if (err) { imap.end(); return reject(err); }
        const f = imap.fetch(uid, { bodies: '', markSeen: true });
        f.on('message', msg => {
          let buf = '';
          msg.on('body', s => s.on('data', c => { buf += c; }));
          msg.once('end', async () => {
            imap.end();
            try {
              const p = await simpleParser(buf);
              resolve({
                from:    p.from?.text    || '',
                to:      p.to?.text      || '',
                subject: p.subject       || '',
                date:    p.date          || null,
                text:    p.text          || '',
                html:    p.html          || null,
              });
            } catch (e) { reject(e); }
          });
        });
        f.once('error', reject);
      });
    });
    imap.connect();
  });
}

// ─── API: GET /api/inbox ─────────────────────────────────────────────────────
exports.getInbox = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const decoded = await verifyToken(req);
      if (!isOwner(decoded)) return res.status(403).json({ error: 'Forbidden' });
      const folder = safeFolder(req.query.folder);
      const limit  = Math.min(parseInt(req.query.limit || '25') || 25, 50);
      const emails = await imapFetchHeaders(getZohoCfg(), folder, limit);
      res.json({ ok: true, folder, emails });
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message });
    }
  });
});

// ─── API: GET /api/email?uid=&folder= ────────────────────────────────────────
exports.getEmail = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const decoded = await verifyToken(req);
      if (!isOwner(decoded)) return res.status(403).json({ error: 'Forbidden' });
      const uid = parseInt(req.query.uid);
      if (!uid || uid < 1) return res.status(400).json({ error: 'Invalid uid' });
      const folder = safeFolder(req.query.folder);
      const email = await imapFetchBody(getZohoCfg(), folder, uid);
      res.json({ ok: true, email });
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message });
    }
  });
});

// ─── API: POST /api/send ─────────────────────────────────────────────────────
exports.sendEmail = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    try {
      const decoded = await verifyToken(req);
      if (!isOwner(decoded)) return res.status(403).json({ error: 'Forbidden' });

      const { to, subject, body } = req.body || {};
      if (!to || !subject || !body) return res.status(400).json({ error: 'Missing to / subject / body' });

      // Basic email validation — no blind trust of user input
      if (typeof to !== 'string' || !/^[^\s@]{1,64}@[^\s@]{1,253}\.[^\s@]{2,63}$/.test(to.trim())) {
        return res.status(400).json({ error: 'Invalid recipient address' });
      }
      if (typeof subject !== 'string' || subject.length > 998) return res.status(400).json({ error: 'Subject too long' });
      if (typeof body !== 'string' || body.length > 100000) return res.status(400).json({ error: 'Body too long' });

      const cfg = getZohoCfg();
      const transport = nodemailer.createTransport({
        host: cfg.smtpHost, port: cfg.smtpPort,
        secure: true,
        auth: { user: cfg.user, pass: cfg.pass },
      });
      await transport.sendMail({
        from: `"Eddie | MLEbotics" <${cfg.user}>`,
        to: to.trim(),
        subject: subject.trim(),
        text: body,
      });
      res.json({ ok: true });
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message });
    }
  });
});

// ─── API: POST /api/search ──────────────────────────────────────────────────
exports.searchSite = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    try {
      const { query } = req.body || {};
      if (!query || typeof query !== 'string' || query.trim().length < 2) {
        return res.status(400).json({ error: 'Query too short' });
      }

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) return res.status(500).json({ error: 'Missing GEMINI_API_KEY' });

      const prompt = [
        'You are an assistant that returns JSON only.',
        'Given the search index and a user query, return a JSON object:',
        '{"summary": string, "results": [{"id": string, "title": string, "url": string}]}',
        'Pick at most 6 results. Use only ids that exist in the index.',
        'Query: ' + query.trim(),
        'Index: ' + JSON.stringify(searchIndex),
      ].join('\n');

      const resp = await fetch(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=' + apiKey,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.2, maxOutputTokens: 512 },
          }),
        }
      );

      if (!resp.ok) {
        const text = await resp.text();
        return res.status(500).json({ error: 'AI request failed', details: text.slice(0, 400) });
      }

      const data = await resp.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';

      let parsed;
      try {
        parsed = JSON.parse(text);
      } catch {
        return res.status(500).json({ error: 'AI response was not JSON' });
      }

      const all = [
        ...searchIndex.pages,
        ...searchIndex.projects,
        ...searchIndex.posts,
      ];

      const results = (parsed.results || [])
        .map(r => all.find(a => a.id === r.id))
        .filter(Boolean)
        .slice(0, 6)
        .map(r => ({ id: r.id, title: r.title, url: r.url }));

      return res.json({ summary: parsed.summary || '', results });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });
});

// ─── API: POST /api/messages/send ────────────────────────────────────────────
exports.sendMessage = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    try {
      const decoded = await verifyToken(req);
      const { text } = req.body || {};
      if (!text || typeof text !== 'string' || text.trim().length === 0) {
        return res.status(400).json({ error: 'Message cannot be empty' });
      }
      if (text.length > 2000) return res.status(400).json({ error: 'Message too long (max 2000 chars)' });

      await db.collection('messages').add({
        from:  decoded.email,
        name:  decoded.name || decoded.email,
        to:    'eddie@mlebotics.com',
        text:  text.trim(),
        ts:    admin.firestore.FieldValue.serverTimestamp(),
        read:  false,
      });
      res.json({ ok: true });
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message });
    }
  });
});

// ─── API: GET /api/messages ───────────────────────────────────────────────────
exports.getMessages = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const decoded = await verifyToken(req);
      let q;
      if (isOwner(decoded)) {
        // Owner sees all messages sent to them
        q = db.collection('messages').where('to', '==', 'eddie@mlebotics.com')
              .orderBy('ts', 'desc').limit(100);
      } else {
        // Non-owner sees only their own messages
        q = db.collection('messages').where('from', '==', decoded.email)
              .orderBy('ts', 'desc').limit(50);
      }
      const snap = await q.get();
      const messages = snap.docs.map(d => {
        const data = d.data();
        return { id: d.id, from: data.from, name: data.name, text: data.text, ts: data.ts?.toDate?.() || null, read: data.read };
      });
      res.json({ ok: true, messages });
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message });
    }
  });
});

// ─── API: POST /api/messages/reply (owner only) ───────────────────────────────
exports.replyMessage = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    try {
      const decoded = await verifyToken(req);
      if (!isOwner(decoded)) return res.status(403).json({ error: 'Forbidden' });
      const { to, text } = req.body || {};
      if (!to || !text || typeof text !== 'string' || text.trim().length === 0) {
        return res.status(400).json({ error: 'Missing to or text' });
      }
      await db.collection('messages').add({
        from:  'eddie@mlebotics.com',
        name:  'Eddie | MLEbotics',
        to:    to,
        text:  text.trim(),
        ts:    admin.firestore.FieldValue.serverTimestamp(),
        read:  false,
        reply: true,
      });
      res.json({ ok: true });
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message });
    }
  });
});
