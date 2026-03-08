-- EA Trading Dashboard v5.0 Database Schema
-- SQLite with WAL mode for better concurrency

-- Enable WAL mode and optimizations
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA cache_size=-64000;
PRAGMA temp_store=MEMORY;
PRAGMA auto_vacuum=INCREMENTAL;

-- Accounts Table
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_number INTEGER UNIQUE NOT NULL,
    name TEXT NOT NULL,
    broker TEXT,
    platform TEXT CHECK(platform IN ('MT4', 'MT5')) DEFAULT 'MT4',
    category TEXT CHECK(category IN ('live', 'copy', 'demo')) DEFAULT 'demo',
    currency TEXT CHECK(currency IN ('USD', 'EUR', 'GBP')) DEFAULT 'USD',
    manual_deposit REAL DEFAULT 0 CHECK(manual_deposit >= 0),
    auto_deposits REAL DEFAULT 0 CHECK(auto_deposits >= 0),
    online_timeout INTEGER DEFAULT 60 CHECK(online_timeout >= 10),
    start_date TIMESTAMP,
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'deleted')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_webhook TIMESTAMP
);

-- Trades Table (historical + open)
CREATE TABLE IF NOT EXISTS trades (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    trade_id INTEGER NOT NULL,
    symbol TEXT NOT NULL,
    type TEXT CHECK(type IN ('BUY', 'SELL')),
    volume REAL CHECK(volume > 0),
    open_price REAL CHECK(open_price > 0),
    close_price REAL,
    profit REAL,
    open_time TIMESTAMP NOT NULL,
    close_time TIMESTAMP,
    is_open BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    UNIQUE(account_id, trade_id),
    CHECK(close_time IS NULL OR close_time >= open_time)
);

-- Daily Performance Snapshots
CREATE TABLE IF NOT EXISTS snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    date DATE NOT NULL,
    balance REAL,
    equity REAL,
    profit REAL,
    deposit REAL,
    trades_count INTEGER,
    win_rate REAL CHECK(win_rate BETWEEN 0 AND 100),
    profit_factor REAL CHECK(profit_factor >= 0),
    drawdown REAL CHECK(drawdown >= 0),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    UNIQUE(account_id, date)
);

-- Webhook Logs (audit trail + debugging)
CREATE TABLE IF NOT EXISTS webhook_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_number INTEGER,
    ea_name TEXT,
    payload TEXT,
    status TEXT CHECK(status IN ('success', 'error')) NOT NULL,
    error_message TEXT,
    processing_time_ms INTEGER,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_accounts_number ON accounts(account_number);
CREATE INDEX IF NOT EXISTS idx_accounts_status ON accounts(status);
CREATE INDEX IF NOT EXISTS idx_trades_account_open ON trades(account_id, is_open);
CREATE INDEX IF NOT EXISTS idx_trades_close_time ON trades(close_time) WHERE is_open = 0;
CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);
CREATE INDEX IF NOT EXISTS idx_snapshots_account_date ON snapshots(account_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_received ON webhook_logs(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_status ON webhook_logs(status);

-- Trigger: Update accounts.updated_at on changes
CREATE TRIGGER IF NOT EXISTS update_accounts_timestamp 
AFTER UPDATE ON accounts
BEGIN
    UPDATE accounts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger: Update trades to closed when close_time is set
CREATE TRIGGER IF NOT EXISTS close_trade_trigger
AFTER UPDATE OF close_time ON trades
WHEN NEW.close_time IS NOT NULL AND OLD.close_time IS NULL
BEGIN
    UPDATE trades SET is_open = 0 WHERE id = NEW.id;
END;
