/**
 * setup_domain.js
 * Automates adding runningcompanion.run + www to Firebase Hosting
 * via Google Site Verification API + Firebase Hosting API.
 *
 * Run: node tools/setup_domain.js
 */

const https = require('https');
const http = require('http');
const { execSync } = require('child_process');
const readline = require('readline');

// Firebase/Google OAuth client (firebase-tools public client)
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8yvTMqSe6xJmIunid';
const REDIRECT_PORT = 9005;
const REDIRECT_URI = `http://localhost:${REDIRECT_PORT}`;

const SCOPES = [
  'https://www.googleapis.com/auth/siteverification',
  'https://www.googleapis.com/auth/firebase.hosting',
  'https://www.googleapis.com/auth/cloud-platform',
  'email',
  'openid',
].join(' ');

const SITE_ID = 'runningcompanion';
const DOMAINS = ['runningcompanion.run', 'www.runningcompanion.run'];

function request(method, hostname, path, body, accessToken, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const headers = { ...extraHeaders };
    if (accessToken) headers['Authorization'] = 'Bearer ' + accessToken;
    if (body) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(body);
    }
    const req = https.request({ hostname, path, method, headers }, res => {
      let d = ''; res.on('data', c => d += c);
      res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function exchangeCode(code) {
  const params = new URLSearchParams({
    code, client_id: CLIENT_ID, client_secret: CLIENT_SECRET,
    redirect_uri: REDIRECT_URI, grant_type: 'authorization_code'
  }).toString();
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'oauth2.googleapis.com', path: '/token', method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(params) }
    }, res => {
      let d = ''; res.on('data', c => d += c);
      res.on('end', () => resolve(JSON.parse(d)));
    });
    req.on('error', reject);
    req.write(params); req.end();
  });
}

function waitForCode() {
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      const url = new URL(req.url, `http://localhost:${REDIRECT_PORT}`);
      const code = url.searchParams.get('code');
      const error = url.searchParams.get('error');
      res.writeHead(200, { 'Content-Type': 'text/html' });
      if (code) {
        res.end('<html><body style="font-family:sans-serif;padding:40px"><h2 style="color:green">✓ Authorized!</h2><p>You can close this tab.</p></body></html>');
        server.close();
        resolve(code);
      } else {
        res.end('<html><body><h2 style="color:red">Authorization failed: ' + (error || 'unknown') + '</h2></body></html>');
        server.close();
        reject(new Error('Auth failed: ' + error));
      }
    });
    server.listen(REDIRECT_PORT, () => {
      console.log(`\nLocal server listening on port ${REDIRECT_PORT}...`);
    });
    server.on('error', reject);
  });
}

async function main() {
  console.log('=== Firebase Custom Domain Setup: runningcompanion.run ===\n');

  // Build auth URL
  const authUrl = 'https://accounts.google.com/o/oauth2/v2/auth?' + new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    scope: SCOPES,
    access_type: 'offline',
    prompt: 'consent',
  }).toString();

  console.log('Opening browser for Google authorization...');
  console.log('(If browser does not open, visit this URL manually:)');
  console.log(authUrl + '\n');

  try {
    execSync(`start "" "${authUrl}"`);
  } catch (e) {
    // ignore - browser may open anyway
  }

  const code = await waitForCode();
  console.log('\nAuthorization code received, exchanging for token...');

  const tokenData = await exchangeCode(code);
  if (!tokenData.access_token) {
    console.error('Failed to get token:', JSON.stringify(tokenData));
    process.exit(1);
  }
  const accessToken = tokenData.access_token;
  console.log('Access token obtained.\n');

  // Step 1: Get TXT verification token for apex domain
  console.log('Step 1: Getting TXT verification token for runningcompanion.run...');
  const tokenRes = await request('POST', 'www.googleapis.com', '/siteVerification/v1/token',
    JSON.stringify({ site: { type: 'INET_DOMAIN', identifier: 'runningcompanion.run' }, verificationMethod: 'DNS_TXT' }),
    accessToken);

  const tokenJson = JSON.parse(tokenRes.body);
  if (tokenRes.status !== 200) {
    console.error('Failed to get verification token:', JSON.stringify(tokenJson, null, 2));
    process.exit(1);
  }

  const txtValue = tokenJson.token;
  console.log('\n✓ TXT Verification Token obtained!\n');
  console.log('══════════════════════════════════════════════════════════');
  console.log('ADD THIS DNS RECORD IN NAMECHEAP → Advanced DNS:');
  console.log('');
  console.log('  Type:  TXT');
  console.log('  Host:  @');
  console.log('  Value: ' + txtValue);
  console.log('  TTL:   Automatic');
  console.log('══════════════════════════════════════════════════════════\n');

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  await new Promise(resolve => rl.question('Press ENTER after adding the TXT record in Namecheap...', () => { rl.close(); resolve(); }));

  console.log('\nStep 2: Verifying domain ownership with Google...');
  const verifyRes = await request('POST', 'www.googleapis.com',
    '/siteVerification/v1/webResource?verificationMethod=DNS_TXT',
    JSON.stringify({ site: { type: 'INET_DOMAIN', identifier: 'runningcompanion.run' }, verificationMethod: 'DNS_TXT' }),
    accessToken);

  const verifyJson = JSON.parse(verifyRes.body);
  if (verifyRes.status !== 200) {
    console.error('\n✗ Verification failed:', JSON.stringify(verifyJson, null, 2));
    console.log('\nDNS changes can take 5–60 minutes. Re-run this script once propagated.');
    console.log('You can check propagation at: https://dnschecker.org/#TXT/runningcompanion.run');
    process.exit(1);
  }

  console.log('✓ Domain ownership VERIFIED!\n');

  // Step 3: Add domains to Firebase Hosting
  for (const domain of DOMAINS) {
    console.log(`Step 3: Adding ${domain} to Firebase Hosting...`);
    const addRes = await request('POST', 'firebasehosting.googleapis.com',
      `/v1beta1/sites/${SITE_ID}/domains`,
      JSON.stringify({ site: SITE_ID, domainName: domain }),
      accessToken);

    const addJson = JSON.parse(addRes.body);
    if (addRes.status === 200 || addRes.status === 409) {
      console.log(`✓ ${domain} added (or already exists)`);
    } else {
      console.error(`✗ Failed to add ${domain}:`, JSON.stringify(addJson, null, 2));
    }
  }

  // Step 4: Fetch the DNS records Firebase needs
  console.log('\nStep 4: Fetching required DNS records from Firebase...');
  await new Promise(r => setTimeout(r, 2000)); // brief wait

  for (const domain of DOMAINS) {
    const detailRes = await request('GET', 'firebasehosting.googleapis.com',
      `/v1beta1/sites/${SITE_ID}/domains/${domain}`, null, accessToken);
    if (detailRes.status !== 200) {
      // domain may not exist yet if verification is still pending
      console.log(`  ${domain}: still provisioning or not added.`);
      continue;
    }
    const detail = JSON.parse(detailRes.body);
    console.log(`\n  ${domain}:`);
    if (detail.provisioning) {
      const p = detail.provisioning;
      if (p.expectedIps) {
        p.expectedIps.forEach(ip => console.log(`    A record → ${ip}`));
      }
      if (p.dnsRequired) {
        p.dnsRequired.forEach(r => console.log(`    ${r.type} ${r.domainName} → ${r.rdata}`));
      }
    }
    console.log('  Status:', detail.status || 'pending');
  }

  console.log('\n══════════════════════════════════════════════════════════');
  console.log('FINAL DNS RECORDS TO ADD IN NAMECHEAP (Advanced DNS):');
  console.log('');
  console.log('  Type   Host   Value');
  console.log('  A      @      199.36.158.100   (Firebase IP)');
  console.log('  CNAME  www    runningcompanion.run.');
  console.log('');
  console.log('Remove any existing A records for @ and CNAME for www first.');
  console.log('══════════════════════════════════════════════════════════');
  console.log('\nDone! Firebase will auto-provision SSL once DNS propagates.');
}

main().catch(e => { console.error(e); process.exit(1); });
