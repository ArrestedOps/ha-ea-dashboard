#!/usr/bin/env python3
"""
EA Trading Dashboard v3.0
Enhanced backend with live trades, currency handling, and account management
"""

import os
import json
import logging
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import requests

# Setup
app = Flask(__name__, static_folder='static')
CORS(app)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

DATA_FILE = '/data/ea_data.json'
EXCHANGE_RATE_API = 'https://api.exchangerate-api.com/v4/latest/USD'

# Initialize data
def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                data = json.load(f)
                # Ensure proper structure
                if 'accounts' not in data:
                    data['accounts'] = []
                if 'settings' not in data:
                    data['settings'] = {'display_currency': 'USD', 'last_exchange_rate': 1.0}
                return data
        except Exception as e:
            logger.error(f'Error loading data: {e}')
    
    # Return empty structure
    return {
        'accounts': [], 
        'settings': {
            'display_currency': 'USD', 
            'last_exchange_rate': 1.0
        }
    }

def save_data(data):
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    logger.info('Data saved to disk')

# Get current exchange rate
def get_exchange_rate():
    try:
        response = requests.get(EXCHANGE_RATE_API, timeout=5)
        if response.status_code == 200:
            data = response.json()
            return data['rates'].get('EUR', 0.92)  # USD to EUR
    except Exception as e:
        logger.warning(f'Failed to fetch exchange rate: {e}')
    return 0.92  # Fallback rate

# Convert currency
def convert_currency(amount, from_curr, to_curr, rate):
    if from_curr == to_curr:
        return amount
    if from_curr == 'USD' and to_curr == 'EUR':
        return amount * rate
    if from_curr == 'EUR' and to_curr == 'USD':
        return amount / rate
    return amount

# Routes
@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

@app.route('/api/status')
def status():
    data = load_data()
    return jsonify({
        'success': True,
        'status': {
            'accounts_count': len(data['accounts']),
            'total_accounts': len(data['accounts']),
            'last_check': datetime.now().isoformat(),
            'version': '3.0.0'
        }
    })

@app.route('/api/accounts')
def get_accounts():
    data = load_data()
    exchange_rate = get_exchange_rate()
    data['settings']['last_exchange_rate'] = exchange_rate
    save_data(data)
    
    accounts_summary = []
    for acc in data['accounts']:
        if acc.get('status') != 'deleted':
            # Calculate stats
            trades = acc.get('trades', [])
            total_profit = sum(t.get('profit', 0) for t in trades)
            winning_trades = [t for t in trades if t.get('profit', 0) > 0]
            losing_trades = [t for t in trades if t.get('profit', 0) < 0]
            
            win_rate = (len(winning_trades) / len(trades) * 100) if trades else 0
            
            gross_profit = sum(t['profit'] for t in winning_trades)
            gross_loss = abs(sum(t['profit'] for t in losing_trades))
            profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else 0
            
            # Drawdown calculation
            deposit = acc.get('deposit', acc.get('current_balance', 0) - total_profit)
            peak = deposit
            max_dd = 0
            
            sorted_trades = sorted(trades, key=lambda x: x.get('close_time', ''))
            running_balance = deposit
            
            for trade in sorted_trades:
                running_balance += trade.get('profit', 0)
                if running_balance > peak:
                    peak = running_balance
                dd = ((peak - running_balance) / peak * 100) if peak > 0 else 0
                if dd > max_dd:
                    max_dd = dd
            
            # Days running
            if trades:
                first_trade = min(trades, key=lambda x: x.get('open_time', ''))
                days = (datetime.now() - datetime.fromisoformat(first_trade['open_time'].replace('Z', '+00:00'))).days
            else:
                days = 0
            
            accounts_summary.append({
                'id': acc['id'],
                'name': acc['name'],
                'account_number': acc['account_number'],
                'broker': acc.get('broker', 'Unknown'),
                'platform': acc.get('platform', 'MT4'),
                'category': acc.get('category', 'demo'),
                'type': acc.get('type', 'Live'),
                'currency': acc.get('currency', 'USD'),
                'deposit': deposit,
                'current_balance': acc.get('current_balance', 0),
                'total_profit': total_profit,
                'total_trades': len(trades),
                'winning_trades': len(winning_trades),
                'losing_trades': len(losing_trades),
                'win_rate': round(win_rate, 2),
                'profit_factor': round(profit_factor, 2),
                'max_drawdown': round(max_dd, 2),
                'days_running': days,
                'withdrawals': acc.get('withdrawals', 0),
                'floating_pl': acc.get('floating_pl', 0),
                'status': acc.get('status', 'active'),
                'last_update': acc.get('last_update', datetime.now().isoformat())
            })
    
    return jsonify({
        'success': True,
        'accounts': accounts_summary,
        'exchange_rate': exchange_rate,
        'settings': data['settings']
    })

@app.route('/api/accounts/<int:account_id>')
def get_account(account_id):
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    
    if not account:
        return jsonify({'success': False, 'error': 'Account not found'}), 404
    
    return jsonify({'success': True, 'account': account})

@app.route('/api/accounts/<int:account_id>/trades')
def get_account_trades(account_id):
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    
    if not account:
        return jsonify({'success': False, 'error': 'Account not found'}), 404
    
    trades = account.get('trades', [])
    # Sort by close time, newest first
    trades_sorted = sorted(trades, key=lambda x: x.get('close_time', ''), reverse=True)
    
    return jsonify({
        'success': True,
        'trades': trades_sorted,
        'total': len(trades_sorted)
    })

@app.route('/api/live-trades')
def get_live_trades():
    """Get all currently open trades across all accounts"""
    data = load_data()
    live_trades = []
    
    for acc in data['accounts']:
        if acc.get('status') != 'deleted':
            open_trades = acc.get('open_trades', [])
            for trade in open_trades:
                live_trades.append({
                    **trade,
                    'account_name': acc['name'],
                    'account_id': acc['id']
                })
    
    # Sort by open time
    live_trades_sorted = sorted(live_trades, key=lambda x: x.get('open_time', ''), reverse=True)
    
    return jsonify({
        'success': True,
        'live_trades': live_trades_sorted[:10],  # Max 10
        'total': len(live_trades_sorted)
    })

@app.route('/api/today-trades')
def get_today_trades():
    """Get all trades closed today across all accounts"""
    data = load_data()
    today = datetime.now().date()
    today_trades = []
    
    for acc in data['accounts']:
        if acc.get('status') != 'deleted':
            trades = acc.get('trades', [])
            for trade in trades:
                close_time_str = trade.get('close_time', '')
                if close_time_str:
                    try:
                        close_time = datetime.fromisoformat(close_time_str.replace('Z', '+00:00'))
                        if close_time.date() == today:
                            today_trades.append({
                                **trade,
                                'account_name': acc['name'],
                                'account_id': acc['id']
                            })
                    except:
                        pass
    
    # Sort by close time
    today_trades_sorted = sorted(today_trades, key=lambda x: x.get('close_time', ''), reverse=True)
    
    return jsonify({
        'success': True,
        'today_trades': today_trades_sorted[:10],  # Max 10
        'total': len(today_trades_sorted)
    })

@app.route('/api/accounts/<int:account_id>', methods=['PUT'])
def update_account(account_id):
    """Update account settings"""
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    
    if not account:
        return jsonify({'success': False, 'error': 'Account not found'}), 404
    
    updates = request.json
    
    # Update allowed fields
    if 'name' in updates:
        account['name'] = updates['name']
    if 'broker' in updates:
        account['broker'] = updates['broker']
    if 'type' in updates:
        account['type'] = updates['type']
    if 'category' in updates:
        account['category'] = updates['category']
    if 'currency' in updates:
        account['currency'] = updates['currency']
    if 'deposit' in updates:
        account['deposit'] = float(updates['deposit'])
    if 'withdrawals' in updates:
        account['withdrawals'] = float(updates['withdrawals'])
    
    account['last_update'] = datetime.now().isoformat()
    
    save_data(data)
    logger.info(f'Account {account_id} updated')
    
    return jsonify({'success': True, 'account': account})

@app.route('/api/accounts/<int:account_id>', methods=['DELETE'])
def delete_account(account_id):
    """Soft delete account"""
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    
    if not account:
        return jsonify({'success': False, 'error': 'Account not found'}), 404
    
    account['status'] = 'deleted'
    account['deleted_at'] = datetime.now().isoformat()
    
    save_data(data)
    logger.info(f'Account {account_id} deleted')
    
    return jsonify({'success': True, 'message': 'Account deleted'})

@app.route('/api/settings', methods=['GET', 'POST'])
def settings():
    """Get or update global settings"""
    data = load_data()
    
    if request.method == 'POST':
        updates = request.json
        if 'display_currency' in updates:
            data['settings']['display_currency'] = updates['display_currency']
        save_data(data)
        logger.info('Settings updated')
    
    return jsonify({
        'success': True,
        'settings': data['settings']
    })

@app.route('/api/webhook/trade', methods=['POST'])
def webhook_trade():
    """Receive trade from MT4/MT5 EA"""
    try:
        payload = request.json
        
        # Validate secret
        secret = payload.get('secret', '')
        # TODO: Validate against stored secret
        
        account_number = payload.get('account_number')
        ea_name = payload.get('ea_name')
        trade_data = payload.get('trade', {})
        
        if not account_number or not ea_name or not trade_data:
            return jsonify({'success': False, 'error': 'Missing data'}), 400
        
        data = load_data()
        
        # Find or create account
        account = next((a for a in data['accounts'] 
                       if a['account_number'] == account_number and a['name'] == ea_name), None)
        
        if not account:
            # Create new account
            new_id = max([a['id'] for a in data['accounts']], default=0) + 1
            account = {
                'id': new_id,
                'account_number': account_number,
                'name': ea_name,
                'broker': payload.get('broker', 'Unknown'),
                'platform': payload.get('platform', 'MT4'),
                'category': payload.get('category', 'demo'),
                'type': 'Live',
                'currency': 'USD',
                'current_balance': trade_data.get('balance', 0),
                'trades': [],
                'open_trades': [],
                'deposit': None,  # Will be calculated or set manually
                'withdrawals': 0,
                'floating_pl': 0,
                'status': 'active',
                'created_at': datetime.now().isoformat(),
                'last_update': datetime.now().isoformat()
            }
            data['accounts'].append(account)
            logger.info(f'Auto-created account: {ea_name} ({account_number})')
        
        # Add trade (avoid duplicates)
        trade_id = trade_data.get('trade_id')
        existing = next((t for t in account['trades'] if t.get('trade_id') == trade_id), None)
        
        if not existing:
            account['trades'].append(trade_data)
            account['current_balance'] = trade_data.get('balance', account['current_balance'])
            account['last_update'] = datetime.now().isoformat()
            logger.info(f'Trade added to {ea_name}: {trade_id}')
        
        save_data(data)
        
        return jsonify({'success': True, 'account_id': account['id']})
        
    except Exception as e:
        logger.error(f'Webhook error: {e}')
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    logger.info('EA Trading Dashboard v3.0 starting...')
    
    # Initialize with demo data if empty
    data = load_data()
    if not data.get('accounts'):
        logger.info('No accounts yet, waiting for first trade...')
    
    app.run(host='0.0.0.0', port=8099, debug=False)
