"""
EA Trading Dashboard v5.0 - FastAPI Backend
"""
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import time
from datetime import datetime

from .database import init_db, get_db
from .models import (
    WebhookPayload, WebhookResponse,
    AccountUpdate, AccountsListResponse,
    TradesListResponse
)
from .webhook import process_webhook, log_webhook
from .crud.accounts import (
    get_accounts, get_account_by_id,
    update_account_settings, delete_account
)
from .crud.trades import (
    get_account_trades, get_today_trades, get_live_trades
)

# ============================================================================
# App Lifecycle
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup"""
    print("🚀 Starting EA Dashboard v5.0...")
    await init_db()
    print("✓ Database initialized")
    yield
    print("👋 Shutting down...")

app = FastAPI(
    title="EA Trading Dashboard",
    description="MetaTrader Expert Advisor Performance Tracking",
    version="5.0.0",
    lifespan=lifespan
)

# CORS for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# Webhook Endpoint
# ============================================================================

@app.post('/api/webhook', response_model=WebhookResponse)
async def webhook(payload: WebhookPayload, bg: BackgroundTasks):
    """
    MT4/MT5 Webhook Handler
    
    Receives trading data from Expert Advisors and stores in database.
    - Creates/updates accounts (matched by account_number)
    - Processes closed and open trades
    - Preserves user settings (manual_deposit, online_timeout)
    """
    start_time = time.time()
    
    try:
        async with get_db() as db:
            result = await process_webhook(db, payload)
        
        processing_time = int((time.time() - start_time) * 1000)
        
        # Log success in background
        bg.add_task(log_webhook_bg, payload, 'success', None, processing_time)
        
        return WebhookResponse(
            success=True,
            account_id=result['account_id'],
            message=f"Processed {result['trades_processed']} trades",
            processing_time_ms=processing_time
        )
    
    except Exception as e:
        processing_time = int((time.time() - start_time) * 1000)
        error_msg = str(e)
        
        # Log error in background
        bg.add_task(log_webhook_bg, payload, 'error', error_msg, processing_time)
        
        raise HTTPException(
            status_code=500,
            detail=f"Webhook processing failed: {error_msg}"
        )

async def log_webhook_bg(payload, status, error, processing_time):
    """Background task to log webhook"""
    try:
        async with get_db() as db:
            await log_webhook(db, payload, status, error, processing_time)
    except Exception as e:
        print(f"Failed to log webhook: {e}")

# ============================================================================
# Accounts API
# ============================================================================

@app.get('/api/accounts', response_model=AccountsListResponse)
async def list_accounts(include_deleted: bool = False):
    """
    Get all accounts with statistics
    
    Returns:
    - Account details
    - Performance metrics (profit, gain%, win rate, etc.)
    - Online status
    """
    async with get_db() as db:
        accounts = await get_accounts(db, include_deleted)
    
    return AccountsListResponse(
        success=True,
        accounts=accounts,
        total=len(accounts)
    )

@app.get('/api/accounts/{account_id}')
async def get_account(account_id: int):
    """Get single account with detailed stats"""
    async with get_db() as db:
        account = await get_account_by_id(db, account_id)
    
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    # Add stats
    from .crud.accounts import get_account_stats
    async with get_db() as db:
        stats = await get_account_stats(db, account_id)
    account.update(stats)
    
    return account

@app.put('/api/accounts/{account_id}')
async def update_account(account_id: int, update: AccountUpdate):
    """
    Update account settings
    
    Only updates user-settable fields:
    - manual_deposit
    - currency
    - online_timeout
    
    Webhook updates are preserved!
    """
    async with get_db() as db:
        account = await update_account_settings(db, account_id, update)
    
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    return {'success': True, 'account': account}

@app.delete('/api/accounts/{account_id}')
async def remove_account(account_id: int):
    """Soft delete account (marks as deleted)"""
    async with get_db() as db:
        success = await delete_account(db, account_id)
    
    if not success:
        raise HTTPException(status_code=404, detail="Account not found")
    
    return {'success': True}

# ============================================================================
# Trades API
# ============================================================================

@app.get('/api/accounts/{account_id}/trades', response_model=TradesListResponse)
async def get_trades(
    account_id: int,
    is_open: bool = None,
    page: int = 1,
    page_size: int = 100
):
    """Get trades for an account (paginated)"""
    offset = (page - 1) * page_size
    
    async with get_db() as db:
        trades = await get_account_trades(
            db, account_id, is_open, page_size, offset
        )
    
    return TradesListResponse(
        success=True,
        trades=trades,
        total=len(trades),
        page=page,
        page_size=page_size
    )

@app.get('/api/live-trades')
async def live_trades():
    """Get all currently open trades across all accounts"""
    async with get_db() as db:
        trades = await get_live_trades(db)
    
    return {
        'success': True,
        'live_trades': trades,
        'total': len(trades)
    }

@app.get('/api/today-trades')
async def today_trades():
    """Get all trades closed today"""
    async with get_db() as db:
        trades = await get_today_trades(db)
    
    return {
        'success': True,
        'today_trades': trades,
        'total': len(trades)
    }

# ============================================================================
# Analytics API (Future)
# ============================================================================

@app.get('/api/analytics/summary')
async def analytics_summary():
    """Get overall portfolio summary"""
    async with get_db() as db:
        accounts = await get_accounts(db)
    
    total_balance = sum(acc.get('current_balance', 0) or 0 for acc in accounts if acc['status'] == 'active')
    total_profit = sum(acc.get('total_profit', 0) or 0 for acc in accounts if acc['status'] == 'active')
    total_trades = sum(acc.get('total_trades', 0) or 0 for acc in accounts if acc['status'] == 'active')
    
    return {
        'success': True,
        'total_accounts': len([a for a in accounts if a['status'] == 'active']),
        'total_balance': round(total_balance, 2),
        'total_profit': round(total_profit, 2),
        'total_trades': total_trades
    }

# ============================================================================
# Health Check
# ============================================================================

@app.get('/health')
async def health_check():
    """Health check endpoint"""
    return {
        'status': 'healthy',
        'version': '5.0.0',
        'timestamp': datetime.now().isoformat()
    }

# ============================================================================
# Serve Frontend (static files)
# ============================================================================

app.mount("/", StaticFiles(directory="static", html=True), name="static")
