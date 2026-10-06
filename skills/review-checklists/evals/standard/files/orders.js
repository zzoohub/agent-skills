const express = require('express');
const router = express.Router();
const db = require('../db'); // node-postgres wrapper: db.query(text, params) -> rows
const { Order } = require('../models');
const { requireAuth } = require('../middleware/auth'); // sets req.user = { id, role }
const { getOrder, processRefund } = require('../services/orders');

// GET /orders?userId=123 — list a user's orders
router.get('/orders', requireAuth, async (req, res) => {
  const { userId } = req.query;
  const rows = await db.query(
    `SELECT id, total, status FROM orders WHERE user_id = ${userId} ORDER BY created_at DESC`
  );
  res.json(rows);
});

// GET /orders/:id — fetch a single order
router.get('/orders/:id', requireAuth, async (req, res) => {
  const rows = await db.query('SELECT * FROM orders WHERE id = $1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);
});

// PATCH /orders/:id — update an order
router.patch('/orders/:id', requireAuth, async (req, res) => {
  const rows = await db.query('SELECT id FROM orders WHERE id = $1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  const updated = await Order.update(req.params.id, req.body);
  res.json(updated);
});

// POST /orders/:id/refund — refund part or all of an order
router.post('/orders/:id/refund', requireAuth, async (req, res) => {
  const { amount } = req.body;
  const order = await getOrder(req.params.id);
  if (!order) return res.status(404).json({ error: 'not found' });
  const receipt = await processRefund(order, amount);
  res.json({ refunded: amount, receipt });
});

module.exports = router;
