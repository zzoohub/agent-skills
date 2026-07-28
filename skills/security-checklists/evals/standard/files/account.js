const express = require('express');
const cors = require('cors');
const { execFile } = require('child_process');
const DOMPurify = require('isomorphic-dompurify');
const knex = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Allow the web app (and its Vercel preview deployments) to call this API with cookies.
router.use(cors({ origin: true, credentials: true }));

// POST /account/thumbnail — generate a 200x200 thumbnail from the uploaded avatar
router.post('/account/thumbnail', requireAuth, (req, res) => {
  const src = req.file.path;
  execFile('convert', [src, '-thumbnail', '200x200', `${src}.thumb`], (err) => {
    if (err) return res.status(500).end();
    res.json({ ok: true });
  });
});

// Render a user-authored bio as HTML for the profile page
function renderBio(bioHtml) {
  return `<section class="bio">${DOMPurify.sanitize(bioHtml)}</section>`;
}

async function findUser(userId) {
  return knex('users').where({ id: userId }).first();
}

// Cosmetic: pick a random onboarding tip to show on the dashboard
function tipOfTheDay(tips) {
  return tips[Math.floor(Math.random() * tips.length)];
}

// GET /logout — end the session and return to the login page
router.get('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/login'));
});

module.exports = { router, renderBio, findUser, tipOfTheDay };
