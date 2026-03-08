"""
Webhook handler - processes MT4/MT5 webhook data
"""
from datetime import datetime
import aiosqlite
from typing import Dict

from .models import WebhookPayload
from .crud.accounts import (
    get_account_by_number,
    create_account,
    update_account_from_webhook
)
from .crud.trades import (
    create_or_update_trade,
    close_missing_trades
)

async def process_webhook(db: aiosqlite.Connection, payload: WebhookPayload) -> Dict:
    """
    Process webhook payload
    Returns: {'account_id': int, 'trades_processed': int}
    """
    
    # 1. Find or create account (match by account_number ONLY)
    account = await get_account_by_number(db, payload.account_number)
    
    if not account:
        # Create new account
        account_data = {
            'account_number': payload.account_number,
            'name': payload.ea_name,
            'broker': payload.broker,
            'platform': payload.platform,
            'category': payload.category,
            'currency': payload.currency,
            'auto_deposits': float(payload.total_deposits or 0),
            'start_date': payload.start_date
        }
        account = await create_account(db, account_data)
    
    else:
        # Update existing account (preserve user settings!)
        webhook_data = {
            'name': payload.ea_name,  # Allow name updates
            'broker': payload.broker,
            'platform': payload.platform,
            'category': payload.category,
            'currency': payload.currency,
            'auto_deposits': float(payload.total_deposits or 0),
            'start_date': payload.start_date
        }
        account = await update_account_from_webhook(db, account['id'], webhook_data)
    
    account_id = account['id']
    
    # 2. Process closed trades
    trades_processed = 0
    for trade in payload.trades:
        await create_or_update_trade(db, account_id, trade)
        trades_processed += 1
    
    # 3. Process open trades
    open_trade_ids = []
    for trade in payload.open_trades:
        await create_or_update_trade(db, account_id, trade)
        open_trade_ids.append(trade.trade_id)
        trades_processed += 1
    
    # 4. Close trades that are no longer open
    await close_missing_trades(db, account_id, open_trade_ids)
    
    await db.commit()
    
    return {
        'account_id': account_id,
        'trades_processed': trades_processed
    }

async def log_webhook(
    db: aiosqlite.Connection,
    payload: WebhookPayload,
    status: str,
    error_message: str = None,
    processing_time_ms: int = None
):
    """Log webhook for debugging"""
    import json
    
    await db.execute("""
        INSERT INTO webhook_logs (
            account_number, ea_name, payload, status, 
            error_message, processing_time_ms
        ) VALUES (?, ?, ?, ?, ?, ?)
    """, (
        payload.account_number,
        payload.ea_name,
        json.dumps(payload.dict(), default=str),
        status,
        error_message,
        processing_time_ms
    ))
    await db.commit()
