"""
CRUD operations for accounts
"""
from typing import List, Optional
from datetime import datetime, timedelta
import aiosqlite
from decimal import Decimal

from .models import AccountCreate, AccountUpdate, AccountResponse

async def get_account_by_number(db: aiosqlite.Connection, account_number: int) -> Optional[dict]:
    """Get account by account number"""
    cursor = await db.execute(
        'SELECT * FROM accounts WHERE account_number = ?',
        (account_number,)
    )
    row = await cursor.fetchone()
    return dict(row) if row else None

async def get_account_by_id(db: aiosqlite.Connection, account_id: int) -> Optional[dict]:
    """Get account by ID"""
    cursor = await db.execute(
        'SELECT * FROM accounts WHERE id = ?',
        (account_id,)
    )
    row = await cursor.fetchone()
    return dict(row) if row else None

async def create_account(db: aiosqlite.Connection, account_data: dict) -> dict:
    """Create new account"""
    cursor = await db.execute("""
        INSERT INTO accounts (
            account_number, name, broker, platform, category, currency,
            manual_deposit, auto_deposits, online_timeout, start_date, status, last_webhook
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        account_data['account_number'],
        account_data['name'],
        account_data.get('broker'),
        account_data.get('platform', 'MT4'),
        account_data.get('category', 'demo'),
        account_data.get('currency', 'USD'),
        0,  # manual_deposit
        account_data.get('auto_deposits', 0),
        60,  # default online_timeout
        account_data.get('start_date'),  # User-defined start date
        'active',
        datetime.now()
    ))
    await db.commit()
    
    return await get_account_by_id(db, cursor.lastrowid)

async def update_account_from_webhook(db: aiosqlite.Connection, account_id: int, webhook_data: dict) -> dict:
    """Update account from webhook (preserve user settings!)"""
    await db.execute("""
        UPDATE accounts SET
            name = ?,
            broker = COALESCE(?, broker),
            platform = COALESCE(?, platform),
            category = COALESCE(?, category),
            currency = COALESCE(?, currency),
            auto_deposits = ?,
            start_date = COALESCE(start_date, ?),
            last_webhook = ?,
            status = 'active'
        WHERE id = ?
    """, (
        webhook_data['name'],
        webhook_data.get('broker'),
        webhook_data.get('platform'),
        webhook_data.get('category'),
        webhook_data.get('currency'),
        webhook_data.get('auto_deposits', 0),
        webhook_data.get('start_date'),  # Only set if not already set
        datetime.now(),
        account_id
    ))
    await db.commit()
    
    return await get_account_by_id(db, account_id)

async def update_account_settings(
    db: aiosqlite.Connection, 
    account_id: int, 
    update: AccountUpdate
) -> Optional[dict]:
    """Update user-settable account fields"""
    updates = []
    params = []
    
    if update.manual_deposit is not None:
        updates.append('manual_deposit = ?')
        params.append(float(update.manual_deposit))
    
    if update.currency is not None:
        updates.append('currency = ?')
        params.append(update.currency)
    
    if update.online_timeout is not None:
        updates.append('online_timeout = ?')
        params.append(update.online_timeout)
    
    if update.start_date is not None:
        updates.append('start_date = ?')
        params.append(update.start_date)
    
    if not updates:
        return await get_account_by_id(db, account_id)
    
    params.append(account_id)
    query = f"UPDATE accounts SET {', '.join(updates)} WHERE id = ?"
    
    await db.execute(query, params)
    await db.commit()
    
    return await get_account_by_id(db, account_id)

async def delete_account(db: aiosqlite.Connection, account_id: int) -> bool:
    """Soft delete account"""
    cursor = await db.execute(
        'UPDATE accounts SET status = ? WHERE id = ?',
        ('deleted', account_id)
    )
    await db.commit()
    return cursor.rowcount > 0

async def get_accounts(db: aiosqlite.Connection, include_deleted: bool = False) -> List[dict]:
    """Get all accounts with stats"""
    query = 'SELECT * FROM accounts'
    if not include_deleted:
        query += ' WHERE status = "active"'
    query += ' ORDER BY category, name'
    
    cursor = await db.execute(query)
    accounts = [dict(row) for row in await cursor.fetchall()]
    
    # Add calculated stats for each account
    for acc in accounts:
        acc['deposit'] = (acc.get('manual_deposit', 0) or 0) + (acc.get('auto_deposits', 0) or 0)
        
        # Online status check
        last_webhook = acc.get('last_webhook')
        timeout = acc.get('online_timeout', 60)
        acc['is_online'] = False
        acc['seconds_since_webhook'] = None
        
        if last_webhook:
            try:
                last_dt = datetime.fromisoformat(last_webhook.replace('Z', '+00:00'))
                seconds_since = (datetime.now() - last_dt).total_seconds()
                acc['seconds_since_webhook'] = int(seconds_since)
                acc['is_online'] = seconds_since <= timeout
            except:
                pass
        
        # Get stats from trades
        stats = await get_account_stats(db, acc['id'])
        acc.update(stats)
    
    return accounts

async def get_account_stats(db: aiosqlite.Connection, account_id: int) -> dict:
    """Calculate account statistics from trades"""
    
    # Get all trades for this account
    cursor = await db.execute("""
        SELECT 
            COUNT(*) as total_trades,
            SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) as winning_trades,
            SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) as losing_trades,
            SUM(profit) as total_profit,
            SUM(CASE WHEN profit > 0 THEN profit ELSE 0 END) as gross_profit,
            SUM(CASE WHEN profit < 0 THEN ABS(profit) ELSE 0 END) as gross_loss,
            MAX(profit) as best_trade,
            MIN(profit) as worst_trade
        FROM trades
        WHERE account_id = ? AND is_open = 0
    """, (account_id,))
    
    trade_stats = dict(await cursor.fetchone())
    
    # Get open trades count and floating P/L
    cursor = await db.execute("""
        SELECT COUNT(*) as open_count, SUM(profit) as floating_pl
        FROM trades
        WHERE account_id = ? AND is_open = 1
    """, (account_id,))
    
    open_stats = dict(await cursor.fetchone())
    
    # Calculate metrics
    total_trades = trade_stats['total_trades'] or 0
    winning_trades = trade_stats['winning_trades'] or 0
    gross_profit = trade_stats['gross_profit'] or 0
    gross_loss = trade_stats['gross_loss'] or 0
    
    win_rate = (winning_trades / total_trades * 100) if total_trades > 0 else 0
    profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else 0
    
    # Get account info for deposit and start_date
    acc_cursor = await db.execute(
        'SELECT manual_deposit, auto_deposits, start_date, created_at FROM accounts WHERE id = ?',
        (account_id,)
    )
    acc_row = await acc_cursor.fetchone()
    
    deposit = 0
    days_running = 0
    gain_percent = 0
    
    if acc_row:
        acc_dict = dict(acc_row)
        deposit = (acc_dict.get('manual_deposit', 0) or 0) + (acc_dict.get('auto_deposits', 0) or 0)
        
        # Days running - use start_date if set, otherwise created_at
        start_date_str = acc_dict.get('start_date')
        if not start_date_str:
            start_date_str = acc_dict.get('created_at')
        
        if start_date_str:
            try:
                start_dt = datetime.fromisoformat(start_date_str.replace('Z', '+00:00'))
                days_running = (datetime.now() - start_dt).days
            except:
                pass
        
        # Gain percent
        if deposit > 0:
            gain_percent = (trade_stats['total_profit'] or 0) / deposit * 100
    
    # Calculate max drawdown (simplified - based on worst trade)
    worst_trade = trade_stats['worst_trade'] or 0
    max_drawdown = abs(worst_trade / deposit * 100) if deposit > 0 else 0
    
    return {
        'total_trades': total_trades,
        'open_trades_count': open_stats['open_count'] or 0,
        'total_profit': float(trade_stats['total_profit'] or 0),
        'floating_pl': float(open_stats['floating_pl'] or 0),
        'win_rate': round(win_rate, 2),
        'profit_factor': round(profit_factor, 2),
        'max_drawdown': round(max_drawdown, 2),
        'best_trade': float(trade_stats['best_trade'] or 0),
        'worst_trade': float(trade_stats['worst_trade'] or 0),
        'days_running': days_running,
        'gain_percent': round(gain_percent, 2)
    }
