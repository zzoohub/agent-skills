const fetch = require('node-fetch');

const BLOCKED_HOSTS = ['localhost', '127.0.0.1'];

const ALLOWED_CDNS = {
  avatars: 'https://cdn.example.com',
  docs: 'https://docs.example.com',
};

// Fetch a user-supplied link and return its contents for a preview card.
async function fetchLinkPreview(userUrl) {
  const parsed = new URL(userUrl);
  if (BLOCKED_HOSTS.includes(parsed.hostname)) {
    throw new Error('blocked host');
  }
  const res = await fetch(userUrl, { redirect: 'follow', timeout: 5000 });
  return await res.text();
}

// Fetch an asset from one of our known CDNs. `bucket` selects the CDN; `key` is the object path.
async function fetchAsset(bucket, key) {
  const base = ALLOWED_CDNS[bucket];
  if (!base) throw new Error('unknown bucket');
  const res = await fetch(`${base}/${encodeURIComponent(key)}`);
  return await res.buffer();
}

async function healthCheck() {
  const res = await fetch('https://status.example.com/health', { timeout: 2000 });
  return res.status === 200;
}

module.exports = { fetchLinkPreview, fetchAsset, healthCheck };
