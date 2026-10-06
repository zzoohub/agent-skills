const express = require('express');
const router = express.Router();
const fetch = require('node-fetch');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');

const CDN_BASE = process.env.CDN_BASE; // e.g. https://cdn.internal.example.com

// GET /proxy/image?url=... — proxy a remote image so the browser sees a same-origin URL
router.get('/proxy/image', async (req, res) => {
  const { url } = req.query;
  const upstream = await fetch(url);
  res.set('content-type', upstream.headers.get('content-type'));
  upstream.body.pipe(res);
});

// POST /webhooks — register a webhook the platform will POST events to
router.post('/webhooks', requireAuth, async (req, res) => {
  const { targetUrl, event } = req.body;
  await db.query(
    'INSERT INTO webhooks(user_id, url, event) VALUES ($1, $2, $3)',
    [req.user.id, targetUrl, event]
  );
  res.status(201).json({ ok: true });
});

// GET /assets/:id — serve an image asset from our CDN by numeric id
router.get('/assets/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) return res.status(400).end();
  const upstream = await fetch(`${CDN_BASE}/assets/${id}.jpg`);
  res.set('content-type', 'image/jpeg');
  upstream.body.pipe(res);
});

module.exports = router;
