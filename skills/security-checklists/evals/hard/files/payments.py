from .db import db
from .charges import do_charge, gateway_refund
from .ledger import processed_keys


def charge_wallet(user_id: int, amount: int, idempotency_key: str) -> dict:
    if idempotency_key in processed_keys:
        return {"status": "duplicate"}

    wallet = db.query("SELECT balance FROM wallets WHERE user_id = %s", [user_id])[0]
    if wallet["balance"] < amount:
        raise ValueError("insufficient funds")

    db.execute("UPDATE wallets SET balance = balance - %s WHERE user_id = %s", [amount, user_id])
    charge = do_charge(user_id, amount)

    processed_keys.add(idempotency_key)
    return {"status": "ok", "charge_id": charge.id}


def refund(order_id: int, amount: int) -> dict:
    order = db.query("SELECT total FROM orders WHERE id = %s", [order_id])[0]
    if amount > order["total"]:
        raise ValueError("refund exceeds order total")

    db.execute("INSERT INTO refunds(order_id, amount) VALUES (%s, %s)", [order_id, amount])
    gateway_refund(order_id, amount)
    return {"status": "refunded", "amount": amount}


def reserve_inventory(sku: str, qty: int) -> dict:
    result = db.execute(
        "UPDATE inventory SET stock = stock - %s WHERE sku = %s AND stock >= %s",
        [qty, sku, qty],
    )
    if result.rowcount == 0:
        raise ValueError("out of stock")
    return {"status": "reserved", "sku": sku, "qty": qty}
