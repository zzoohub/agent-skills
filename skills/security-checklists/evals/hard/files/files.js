const path = require('path');
const express = require('express');
const router = express.Router();
const db = require('../db');

const UPLOAD_DIR = '/srv/uploads';

// GET /download?file=... — stream a stored upload back to the user
router.get('/download', (req, res) => {
  const target = path.join(UPLOAD_DIR, req.query.file);
  if (!target.startsWith(UPLOAD_DIR)) {
    return res.status(403).end();
  }
  res.sendFile(target);
});

function sanitize(html) {
  return html.replace(/<script>/gi, '');
}

// POST /comment — store a user comment (rich text allowed)
router.post('/comment', async (req, res) => {
  const clean = sanitize(req.body.html);
  await db.query('INSERT INTO comments(author_id, body) VALUES ($1, $2)', [req.user.id, clean]);
  res.status(201).json({ ok: true });
});

// GET /comments — render all comments
router.get('/comments', async (req, res) => {
  const rows = await db.query('SELECT body FROM comments ORDER BY created_at DESC LIMIT 50');
  res.send(`<ul class="comments">${rows.map((r) => `<li>${r.body}</li>`).join('')}</ul>`);
});

// GET /avatar/:id — serve a user's avatar image
router.get('/avatar/:id', async (req, res) => {
  const rows = await db.query('SELECT path FROM avatars WHERE id = $1', [Number(req.params.id)]);
  if (!rows.length) return res.status(404).end();
  res.sendFile(path.join(UPLOAD_DIR, path.basename(rows[0].path)));
});

module.exports = router;
