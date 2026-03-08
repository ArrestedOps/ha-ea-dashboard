"""
CRUD operations for trades
"""
from typing import List, Optional
from datetime import datetime
import aiosqlite

from .models import TradeCreate

async def create_or_update_trade(
    db: aiosqlite.Connection,
    account_id: int,
    trade: TradeCreate
) -> int:
    """Create or update a trade (upsert)"""
    
    # Check if trade already exists
    cursor = await db.execute("""
        SELECT id, is_open FROM trades 
        WHERE account_id = ? AND trade_id = ?
    """, (account_id, trade.trade_id))
    
    existing = await cursor.fetchone()
    
    if existing:
        # Update existing trade
        trade_db_id = existing[0]
        was_open = existing[1]
        
        # If trade is now closed (has close_time), update it
        if trade.close_time is not None:
            await db.execute("""
                UPDATE trades SET
                    close_price = ?,
                    profit = ?,
                    close_time = ?,
                    is_open = 0
                WHERE id = ?
            """, (
                float(trade.close_price) if trade.close_price else None,
                float(trade.profit) if trade.profit else None,
                trade.close_time,
                trade_db_id
            ))
        else:
            # Update open trade (profit may change)
            await db.execute("""
                UPDATE trades SET profit = ? WHERE id = ?
            """, (float(trade.profit) if trade.profit else None, trade_db_id))
        
        return trade_db_id
    
    else:
        # Create new trade
        is_open = 1 if trade.close_time is None else 0
        
        cursor = await db.execute("""
            INSERT INTO trades (
                account_id, trade_id, symbol, type, volume,
                open_price, close_price, profit,
                open_time, close_time, is_open
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            account_id,
            trade.trade_id,
            trade.symbol,
            trade.type,
            float(trade.volume),
            float(trade.open_price),
            float(trade.close_price) if trade.close_price else None,
            float(trade.profit) if trade.profit else None,
            trade.open_time,
            trade.close_time,
            is_open
        ))
        
        return cursor.lastrowid

async def get_account_trades(
    db: aiosqlite.Connection,
    account_id: int,
    is_open: Optional[bool] = None,
    limit: int = 100,
    offset: int = 0
) -> List[dict]:
    """Get trades for an account"""
    
    query = 'SELECT * FROM trades WHERE account_id = ?'
    params = [account_id]
    
    if is_open is not None:
        query += ' AND is_open = ?'
        params.append(1 if is_open else 0)
    
    query += ' ORDER BY open_time DESC LIMIT ? OFFSET ?'
    params.extend([limit, offset])
    
    cursor = await db.execute(query, params)
    return [dict(row) for row in await cursor.fetchall()]

async def get_today_trades(db: aiosqlite.Connection) -> List[dict]:
    """Get all trades closed today"""
    cursor = await db.execute("""
        SELECT t.*, a.name as account_name, a.currency
        FROM trades t
        JOIN accounts a ON t.account_id = a.id
        WHERE DATE(t.close_time) = DATE('now')
        AND t.is_open = 0
        ORDER BY t.close_time DESC
    """)
    return [dict(row) for row in await cursor.fetchall()]

async def get_live_trades(db: aiosqlite.Connection) -> List[dict]:
    """Get all open trades"""
    cursor = await db.execute("""
        SELECT t.*, a.name as account_name, a.currency
        FROM trades t
        JOIN accounts a ON t.account_id = a.id
        WHERE t.is_open = 1
        ORDER BY t.open_time DESC
    """)
    return [dict(row) for row in await cursor.fetchall()]

async def close_missing_trades(db: aiosqlite.Connection, account_id: int, open_trade_ids: List[int]):
    """Close trades that are no longer in the open trades list"""
    if not open_trade_ids:
        # Close all open trades for this account
        await db.execute("""
            UPDATE trades SET is_open = 0, close_time = CURRENT_TIMESTAMP
            WHERE account_id = ? AND is_open = 1
        """, (account_id,))
    else:
        # Close trades not in the list
        placeholders = ','.join('?' * len(open_trade_ids))
        await db.execute(f"""
            UPDATE trades SET is_open = 0, close_time = CURRENT_TIMESTAMP
            WHERE account_id = ? AND is_open = 1 AND trade_id NOT IN ({placeholders})
        """, [account_id] + open_trade_ids)

async def cleanup_old_trades(db: aiosqlite.Connection, days: int = 730):
    """Delete closed trades older than X days"""
    cursor = await db.execute("""
        DELETE FROM trades
        WHERE is_open = 0 
        AND close_time < datetime('now', ? || ' days')
    """, (f'-{days}',))
    await db.commit()
    return cursor.rowcount
