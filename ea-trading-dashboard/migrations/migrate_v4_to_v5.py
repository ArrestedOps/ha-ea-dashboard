#!/usr/bin/env python3
"""
Migration Script: EA Dashboard v4.x → v5.0
Migrates data from JSON file to SQLite database
"""
import json
import asyncio
import aiosqlite
import sys
from pathlib import Path
from datetime import datetime

# Paths
OLD_DATA_PATH = '/data/data.json'
NEW_DB_PATH = '/data/dashboard.db'
SCHEMA_PATH = Path(__file__).parent.parent / 'rootfs/app/schema.sql'

async def migrate():
    """Execute migration"""
    
    print("=" * 60)
    print("EA Dashboard Migration: v4.x → v5.0")
    print("=" * 60)
    
    # 1. Check if old data exists
    if not Path(OLD_DATA_PATH).exists():
        print(f"❌ Old data file not found: {OLD_DATA_PATH}")
        print("   Nothing to migrate.")
        sys.exit(0)
    
    # 2. Load old JSON data
    print(f"\n📂 Loading data from {OLD_DATA_PATH}...")
    with open(OLD_DATA_PATH, 'r') as f:
        old_data = json.load(f)
    
    old_accounts = old_data.get('accounts', [])
    print(f"   Found {len(old_accounts)} accounts")
    
    # 3. Create new database
    print(f"\n🗄️  Creating new database: {NEW_DB_PATH}...")
    
    # Read schema
    with open(SCHEMA_PATH, 'r') as f:
        schema_sql = f.read()
    
    async with aiosqlite.connect(NEW_DB_PATH) as db:
        # Execute schema
        await db.executescript(schema_sql)
        await db.commit()
        print("   ✓ Schema created")
        
        # 4. Migrate accounts
        print(f"\n👤 Migrating accounts...")
        accounts_migrated = 0
        
        for old_acc in old_accounts:
            if old_acc.get('status') == 'deleted':
                continue
            
            # Extract fields
            account_number = old_acc.get('account_number')
            if not account_number:
                print(f"   ⚠️  Skipping account without number: {old_acc.get('name')}")
                continue
            
            try:
                await db.execute("""
                    INSERT INTO accounts (
                        account_number, name, broker, platform, category, currency,
                        manual_deposit, auto_deposits, online_timeout, start_date, status,
                        created_at, updated_at, last_webhook
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    account_number,
                    old_acc.get('name', ''),
                    old_acc.get('broker'),
                    old_acc.get('platform', 'MT4'),
                    old_acc.get('category', 'demo'),
                    old_acc.get('currency', 'USD'),
                    old_acc.get('manual_deposit', 0),
                    old_acc.get('auto_deposits', 0),
                    old_acc.get('online_timeout', 60),
                    old_acc.get('start_date'),  # May be None for old accounts
                    'active',
                    old_acc.get('created_at', datetime.now().isoformat()),
                    old_acc.get('last_update', datetime.now().isoformat()),
                    old_acc.get('last_webhook')
                ))
                
                account_id = (await db.execute('SELECT last_insert_rowid()')).fetchone()[0]
                accounts_migrated += 1
                
                # 5. Migrate trades for this account
                trades_migrated = 0
                
                # Closed trades
                for trade in old_acc.get('trades', []):
                    try:
                        await db.execute("""
                            INSERT INTO trades (
                                account_id, trade_id, symbol, type, volume,
                                open_price, close_price, profit,
                                open_time, close_time, is_open
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                        """, (
                            account_id,
                            trade.get('trade_id'),
                            trade.get('symbol'),
                            trade.get('type'),
                            trade.get('volume', 0),
                            trade.get('open_price', 0),
                            trade.get('close_price'),
                            trade.get('profit', 0),
                            trade.get('open_time'),
                            trade.get('close_time'),
                        ))
                        trades_migrated += 1
                    except Exception as e:
                        print(f"   ⚠️  Failed to migrate trade {trade.get('trade_id')}: {e}")
                
                # Open trades
                for trade in old_acc.get('open_trades', []):
                    try:
                        await db.execute("""
                            INSERT INTO trades (
                                account_id, trade_id, symbol, type, volume,
                                open_price, close_price, profit,
                                open_time, close_time, is_open
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
                        """, (
                            account_id,
                            trade.get('trade_id'),
                            trade.get('symbol'),
                            trade.get('type'),
                            trade.get('volume', 0),
                            trade.get('open_price', 0),
                            trade.get('close_price'),
                            trade.get('profit', 0),
                            trade.get('open_time'),
                            trade.get('close_time'),
                        ))
                        trades_migrated += 1
                    except Exception as e:
                        print(f"   ⚠️  Failed to migrate open trade {trade.get('trade_id')}: {e}")
                
                print(f"   ✓ {old_acc.get('name')}: {trades_migrated} trades")
                
            except Exception as e:
                print(f"   ❌ Failed to migrate account {old_acc.get('name')}: {e}")
        
        await db.commit()
        print(f"\n✅ Migration complete!")
        print(f"   Accounts: {accounts_migrated}")
        
        # 6. Backup old file
        backup_path = f"{OLD_DATA_PATH}.backup-{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        Path(OLD_DATA_PATH).rename(backup_path)
        print(f"\n💾 Original file backed up: {backup_path}")
        
        # 7. Verify migration
        cursor = await db.execute('SELECT COUNT(*) FROM accounts')
        acc_count = (await cursor.fetchone())[0]
        
        cursor = await db.execute('SELECT COUNT(*) FROM trades')
        trade_count = (await cursor.fetchone())[0]
        
        print(f"\n📊 Database Statistics:")
        print(f"   Accounts: {acc_count}")
        print(f"   Trades: {trade_count}")
        
        print(f"\n🎉 Migration successful!")
        print(f"   You can now start v5.0")

if __name__ == '__main__':
    try:
        asyncio.run(migrate())
    except KeyboardInterrupt:
        print("\n\n⚠️  Migration cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
