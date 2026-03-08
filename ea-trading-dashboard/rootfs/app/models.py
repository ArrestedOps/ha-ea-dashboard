"""
Pydantic models for request/response validation
"""
from pydantic import BaseModel, Field, validator, root_validator
from typing import List, Optional
from datetime import datetime
from decimal import Decimal

# ============================================================================
# Trade Models
# ============================================================================

class TradeBase(BaseModel):
    """Base trade model"""
    trade_id: int
    symbol: str = Field(min_length=1, max_length=20)
    type: str
    volume: Decimal = Field(gt=0)
    open_price: Decimal = Field(gt=0)
    close_price: Optional[Decimal] = None
    profit: Optional[Decimal] = None
    open_time: datetime
    close_time: Optional[datetime] = None
    
    @validator('type')
    def validate_type(cls, v):
        if v not in ['BUY', 'SELL']:
            raise ValueError('Type must be BUY or SELL')
        return v.upper()
    
    @root_validator
    def validate_times(cls, values):
        open_time = values.get('open_time')
        close_time = values.get('close_time')
        if open_time and close_time and close_time < open_time:
            raise ValueError('close_time must be after open_time')
        return values

class TradeCreate(TradeBase):
    """Trade for creation"""
    pass

class TradeResponse(TradeBase):
    """Trade response with additional fields"""
    id: int
    account_id: int
    is_open: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

# ============================================================================
# Webhook Models
# ============================================================================

class WebhookPayload(BaseModel):
    """MT4/MT5 Webhook payload"""
    account_number: int = Field(gt=0)
    ea_name: str = Field(min_length=1, max_length=255)
    broker: Optional[str] = Field(None, max_length=100)
    platform: str = Field(default='MT4')
    category: str = Field(default='demo')
    currency: str = Field(default='USD')
    current_balance: Decimal
    total_deposits: Optional[Decimal] = Field(default=0)
    total_withdrawals: Optional[Decimal] = Field(default=0)
    leverage: Optional[int] = Field(default=0)
    start_date: Optional[datetime] = None  # User-defined start date from MT4/MT5
    trades: List[TradeCreate] = Field(default_factory=list)
    open_trades: List[TradeCreate] = Field(default_factory=list)
    
    @validator('platform')
    def validate_platform(cls, v):
        if v not in ['MT4', 'MT5']:
            raise ValueError('Platform must be MT4 or MT5')
        return v
    
    @validator('category')
    def validate_category(cls, v):
        if v not in ['live', 'copy', 'demo']:
            raise ValueError('Category must be live, copy, or demo')
        return v
    
    @validator('currency')
    def validate_currency(cls, v):
        if v not in ['USD', 'EUR', 'GBP']:
            raise ValueError('Currency must be USD, EUR, or GBP')
        return v

class WebhookResponse(BaseModel):
    """Webhook response"""
    success: bool
    account_id: Optional[int] = None
    message: Optional[str] = None
    processing_time_ms: Optional[int] = None

# ============================================================================
# Account Models
# ============================================================================

class AccountBase(BaseModel):
    """Base account fields"""
    name: str = Field(min_length=1, max_length=255)
    broker: Optional[str] = None
    platform: str = 'MT4'
    category: str = 'demo'
    currency: str = 'USD'

class AccountCreate(AccountBase):
    """Account creation"""
    account_number: int = Field(gt=0)

class AccountUpdate(BaseModel):
    """Account update (only user-settable fields)"""
    manual_deposit: Optional[Decimal] = Field(None, ge=0)
    currency: Optional[str] = None
    online_timeout: Optional[int] = Field(None, ge=10, le=600)
    start_date: Optional[datetime] = None  # Allow updating start date
    
    @validator('currency')
    def validate_currency(cls, v):
        if v and v not in ['USD', 'EUR', 'GBP']:
            raise ValueError('Currency must be USD, EUR, or GBP')
        return v

class AccountResponse(AccountBase):
    """Account response with all fields"""
    id: int
    account_number: int
    manual_deposit: Decimal
    auto_deposits: Decimal
    deposit: Decimal  # Calculated: manual + auto
    online_timeout: int
    status: str
    created_at: datetime
    updated_at: datetime
    last_webhook: Optional[datetime] = None
    
    # Stats (added by CRUD layer)
    current_balance: Optional[Decimal] = None
    total_profit: Optional[Decimal] = None
    total_trades: Optional[int] = None
    open_trades_count: Optional[int] = None
    win_rate: Optional[float] = None
    profit_factor: Optional[float] = None
    max_drawdown: Optional[float] = None
    days_running: Optional[int] = None
    gain_percent: Optional[float] = None
    is_online: Optional[bool] = None
    seconds_since_webhook: Optional[int] = None
    
    class Config:
        from_attributes = True

# ============================================================================
# Snapshot Models
# ============================================================================

class SnapshotCreate(BaseModel):
    """Daily snapshot creation"""
    account_id: int
    date: datetime
    balance: Decimal
    equity: Decimal
    profit: Decimal
    deposit: Decimal
    trades_count: int
    win_rate: float = Field(ge=0, le=100)
    profit_factor: float = Field(ge=0)
    drawdown: float = Field(ge=0)

class SnapshotResponse(BaseModel):
    """Snapshot response"""
    id: int
    account_id: int
    date: datetime
    balance: Decimal
    profit: Decimal
    trades_count: int
    win_rate: float
    
    class Config:
        from_attributes = True

# ============================================================================
# Response Models
# ============================================================================

class AccountsListResponse(BaseModel):
    """List of accounts response"""
    success: bool = True
    accounts: List[AccountResponse]
    total: int

class TradesListResponse(BaseModel):
    """List of trades response"""
    success: bool = True
    trades: List[TradeResponse]
    total: int
    page: int
    page_size: int
