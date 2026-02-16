#!/usr/bin/env python3
"""
EA Trading Dashboard v3.2.0
Complete backend with live trades, deposits, withdrawals, proper calculations
"""

import os
import json
import logging
from datetime import datetime
from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import requests

app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

DATA_FILE = '/data/ea_data.json'
EXCHANGE_RATE_API = 'https://api.exchangerate-api.com/v4/latest/USD'

def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                data = json.load(f)
                if 'accounts' not in data:
                    data['accounts'] = []
                if 'settings' not in data:
                    data['settings'] = {'display_currency': 'USD', 'last_exchange_rate': 1.0}
                return data
        except Exception as e:
            logger.error(f'Error loading data: {e}')
    
    return {'accounts': [], 'settings': {'display_currency': 'USD', 'last_exchange_rate': 1.0}}

def save_data(data):
    try:
        with open(DATA_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        logger.error(f'Error saving data: {e}')

def get_exchange_rate():
    try:
        response = requests.get(EXCHANGE_RATE_API, timeout=5)
        if response.status_code == 200:
            return response.json()['rates'].get('EUR', 0.92)
    except:
        pass
    return 0.92

def parse_date(date_str):
    """Handle both MT4 format (2025.08.18 06:00:06) and ISO format"""
    try:
        if '.' in date_str and ':' in date_str and 'T' not in date_str:
            date_str = date_str.replace('.', '-').replace(' ', 'T')
        return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
    except:
        return None

@app.route('/')
def index():
    return send_file('static/index.html')

@app.route('/api/status')
def status():
    data = load_data()
    return jsonify({
        'success': True,
        'status': {
            'accounts_count': len([a for a in data['accounts'] if a.get('status') != 'deleted']),
            'version': '3.2.0',
            'last_check': datetime.now().isoformat()
        }
    })

@app.route('/api/accounts')
def get_accounts():
    data = load_data()
    exchange_rate = get_exchange_rate()
    data['settings']['last_exchange_rate'] = exchange_rate
    save_data(data)
    
    accounts_summary = []
    total_balance = 0
    total_profit = 0
    total_trades_count = 0
    
    for acc in data['accounts']:
        if acc.get('status') == 'deleted':
            continue
            
        trades = acc.get('trades', [])
        open_trades = acc.get('open_trades', [])
        
        # Calculate profits
        closed_profit = sum(t.get('profit', 0) for t in trades)
        open_profit = sum(t.get('profit', 0) for t in open_trades)
        total_profit_acc = closed_profit + open_profit
        
        winning_trades = [t for t in trades if t.get('profit', 0) > 0]
        losing_trades = [t for t in trades if t.get('profit', 0) < 0]
        
        win_rate = (len(winning_trades) / len(trades) * 100) if trades else 0
        
        gross_profit = sum(t['profit'] for t in winning_trades) if winning_trades else 0
        gross_loss = abs(sum(t['profit'] for t in losing_trades)) if losing_trades else 0
        profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else 0
        
        # Get deposit from account or calculate
        deposit = acc.get('deposit') or acc.get('initial_balance')
        if not deposit or deposit <= 0:
            deposit = acc.get('current_balance', 1000) - closed_profit
            if deposit <= 0:
                deposit = 1000
        
        # Drawdown calculation
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
        days = 0
        if trades:
            first_trade = min(trades, key=lambda x: x.get('open_time', ''))
            first_date = parse_date(first_trade.get('open_time', ''))
            if first_date:
                days = (datetime.now() - first_date).days
        
        # Gain calculation
        gain_percent = ((total_profit_acc / deposit) * 100) if deposit > 0 else 0
        
        current_balance = acc.get('current_balance', 0)
        withdrawals = acc.get('withdrawals', 0)
        
        # Add to totals
        total_balance += current_balance
        total_profit += total_profit_acc
        total_trades_count += len(trades)
        
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
            'current_balance': current_balance,
            'total_profit': round(total_profit_acc, 2),
            'total_trades': len(trades),
            'open_trades_count': len(open_trades),
            'winning_trades': len(winning_trades),
            'losing_trades': len(losing_trades),
            'win_rate': round(win_rate, 2),
            'profit_factor': round(profit_factor, 2),
            'max_drawdown': round(max_dd, 2),
            'days_running': days,
            'withdrawals': withdrawals,
            'floating_pl': round(open_profit, 2),
            'gain_percent': round(gain_percent, 2),
            'status': acc.get('status', 'active'),
            'last_update': acc.get('last_update', datetime.now().isoformat())
        })
    
    return jsonify({
        'success': True,
        'accounts': accounts_summary,
        'exchange_rate': exchange_rate,
        'settings': data['settings'],
        'totals': {
            'total_balance': round(total_balance, 2),
            'total_profit': round(total_profit, 2),
            'total_trades': total_trades_count,
            'total_accounts': len(accounts_summary)
        }
    })

@app.route('/api/accounts/<int:account_id>')
def get_account_detail(account_id):
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    
    if not account or account.get('status') == 'deleted':
        return jsonify({'success': False, 'error': 'Account not found'}), 404
    
    return jsonify({'success': True, 'account': account})

@app.route('/api/accounts/<int:account_id>/trades')
def get_account_trades(account_id):
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    
    if not account:
        return jsonify({'success': False, 'error': 'Account not found'}), 404
    
    trades = account.get('trades', [])
    trades_sorted = sorted(trades, key=lambda x: x.get('close_time', ''), reverse=True)
    
    return jsonify({
        'success': True,
        'trades': trades_sorted,
        'total': len(trades_sorted)
    })

@app.route('/api/live-trades')
def get_live_trades():
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
    
    live_trades_sorted = sorted(live_trades, key=lambda x: x.get('open_time', ''), reverse=True)
    
    return jsonify({
        'success': True,
        'live_trades': live_trades_sorted[:10],
        'total': len(live_trades_sorted)
    })

@app.route('/api/today-trades')
def get_today_trades():
    data = load_data()
    today = datetime.now().date()
    today_trades = []
    
    for acc in data['accounts']:
        if acc.get('status') != 'deleted':
            trades = acc.get('trades', [])
            for trade in trades:
                close_date = parse_date(trade.get('close_time', ''))
                if close_date and close_date.date() == today:
                    today_trades.append({
                        **trade,
                        'account_name': acc['name'],
                        'account_id': acc['id']
                    })
    
    today_trades_sorted = sorted(today_trades, key=lambda x: x.get('close_time', ''), reverse=True)
    
    return jsonify({
        'success': True,
        'today_trades': today_trades_sorted[:10],
        'total': len(today_trades_sorted)
    })

@app.route('/api/accounts/<int:account_id>', methods=['PUT'])
def update_account(account_id):
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    
    if not account:
        return jsonify({'success': False, 'error': 'Account not found'}), 404
    
    updates = request.json
    
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
    data = load_data()
    
    if request.method == 'POST':
        updates = request.json
        if 'display_currency' in updates:
            data['settings']['display_currency'] = updates['display_currency']
        save_data(data)
        logger.info('Settings updated')
    
    return jsonify({'success': True, 'settings': data['settings']})

@app.route('/api/webhook/trade', methods=['POST'])
def webhook_trade():
    try:
        payload = request.json
        account_number = payload.get('account_number')
        ea_name = payload.get('ea_name')
        
        if not account_number or not ea_name:
            return jsonify({'success': False, 'error': 'Missing data'}), 400
        
        data = load_data()
        
        # Find account (even if deleted - reactivate it)
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
                'current_balance': 0,
                'trades': [],
                'open_trades': [],
                'deposit': payload.get('initial_balance'),
                'initial_balance': payload.get('initial_balance'),
                'withdrawals': payload.get('withdrawals', 0),
                'deposits': payload.get('deposits', 0),
                'floating_pl': 0,
                'status': 'active',
                'created_at': datetime.now().isoformat(),
                'last_update': datetime.now().isoformat()
            }
            data['accounts'].append(account)
            logger.info(f'Created account: {ea_name} ({account_number})')
        elif account.get('status') == 'deleted':
            # Reactivate deleted account
            account['status'] = 'active'
            account['trades'] = []  # Clear old trades
            account['open_trades'] = []
            logger.info(f'Reactivated account: {ea_name} ({account_number})')
        
        # Update account info
        if 'initial_balance' in payload:
            account['deposit'] = payload['initial_balance']
            account['initial_balance'] = payload['initial_balance']
        if 'withdrawals' in payload:
            account['withdrawals'] = payload['withdrawals']
        if 'deposits' in payload:
            account['deposits'] = payload['deposits']
        
        # Handle closed trade
        if 'trade' in payload:
            trade_data = payload['trade']
            trade_id = trade_data.get('trade_id')
            existing = next((t for t in account['trades'] if t.get('trade_id') == trade_id), None)
            
            if not existing:
                account['trades'].append(trade_data)
                account['current_balance'] = trade_data.get('balance', account['current_balance'])
                logger.info(f'Trade added: {trade_id}')
        
        # Handle open trade
        if 'open_trade' in payload:
            open_trade_data = payload['open_trade']
            trade_id = open_trade_data.get('trade_id')
            
            # Update or add open trade
            existing_idx = next((i for i, t in enumerate(account['open_trades']) 
                               if t.get('trade_id') == trade_id), None)
            
            if existing_idx is not None:
                account['open_trades'][existing_idx] = open_trade_data
            else:
                account['open_trades'].append(open_trade_data)
            
            # Update floating P/L
            account['floating_pl'] = sum(t.get('profit', 0) for t in account['open_trades'])
        
        account['last_update'] = datetime.now().isoformat()
        save_data(data)
        
        return jsonify({'success': True, 'account_id': account['id']})
        
    except Exception as e:
        logger.error(f'Webhook error: {e}')
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    logger.info('EA Trading Dashboard v3.2.0 starting...')
    
    data = load_data()
    if not data.get('accounts'):
        logger.info('No accounts yet, waiting for first trade...')
    
    app.run(host='0.0.0.0', port=8099, debug=False)
