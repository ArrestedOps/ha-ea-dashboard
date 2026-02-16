"""
EA Trading Dashboard v2.0 - With Webhook Support
Receives trades directly from MT4/MT5 Expert Advisors
"""
import os
import json
import logging
from datetime import datetime, timedelta
from flask import Flask, jsonify, send_from_directory, request
from flask_cors import CORS
from apscheduler.schedulers.background import BackgroundScheduler
import hashlib

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__, static_folder='static', template_folder='static')
CORS(app)

CONFIG_PATH = '/data/options.json'
DATA_PATH = '/data/ea_data.json'
CATEGORIES = {
    'live': {'label': 'Live Konto', 'color': '#00ff87', 'icon': '💰'},
    'demo': {'label': 'Demo Konto', 'color': '#ff9500', 'icon': '🧪'},
    'copy': {'label': 'Copy Trading', 'color': '#00d4ff', 'icon': '📋'},
    'challenge': {'label': 'FTMO Challenge', 'color': '#a78bfa', 'icon': '🏆'}
}

ea_accounts = {}

def load_config():
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                return json.load(f)
        return {'webhook_secret': '', 'mt_accounts': []}
    except Exception as e:
        logger.error(f"Config load error: {e}")
        return {'webhook_secret': '', 'mt_accounts': []}

def save_data():
    try:
        with open(DATA_PATH, 'w') as f:
            json.dump(ea_accounts, f, indent=2)
    except Exception as e:
        logger.error(f"Save error: {e}")

def load_data():
    global ea_accounts
    if os.path.exists(DATA_PATH):
        try:
            with open(DATA_PATH, 'r') as f:
                ea_accounts = json.load(f)
                logger.info(f"Loaded {len(ea_accounts)} accounts")
        except:
            ea_accounts = {}

def get_account_key(account_number, ea_name):
    return f"{account_number}_{ea_name.replace(' ', '_')}"

def calculate_stats(trades):
    if not trades:
        return {
            'total_trades': 0, 'winning_trades': 0, 'losing_trades': 0,
            'total_profit': 0, 'current_balance': 0, 'max_drawdown': 0,
            'win_rate': 0, 'profit_factor': 0
        }
    
    winning = [t for t in trades if t['profit'] > 0]
    losing = [t for t in trades if t['profit'] < 0]
    total_profit = sum(t['profit'] for t in trades)
    gross_profit = sum(t['profit'] for t in winning)
    gross_loss = abs(sum(t['profit'] for t in losing))
    
    # Drawdown calculation
    balances = sorted(trades, key=lambda x: x.get('close_time', x.get('timestamp', '')))
    peak = balances[0]['balance'] if balances else 0
    max_dd = 0
    for trade in balances:
        if trade['balance'] > peak:
            peak = trade['balance']
        dd = ((peak - trade['balance']) / peak * 100) if peak > 0 else 0
        max_dd = max(max_dd, dd)
    
    return {
        'total_trades': len(trades),
        'winning_trades': len(winning),
        'losing_trades': len(losing),
        'total_profit': round(total_profit, 2),
        'current_balance': round(balances[-1]['balance'], 2) if balances else 0,
        'max_drawdown': round(max_dd, 2),
        'win_rate': round((len(winning) / len(trades) * 100), 2) if trades else 0,
        'profit_factor': round((gross_profit / gross_loss), 2) if gross_loss > 0 else 0
    }

# API Routes
@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

@app.route('/api/accounts')
def get_accounts():
    accounts = []
    for key, data in ea_accounts.items():
        if data.get('status') != 'archived':
            account = {
                'id': data['id'],
                'name': data['name'],
                'category': data.get('category', 'live'),
                'platform': data.get('platform', 'MT4'),
                'broker': data.get('broker', 'Unknown'),
                'account_number': data.get('account_number', 0),
                'status': data.get('status', 'active'),
                'last_update': data.get('last_update', '')
            }
            account.update(data.get('stats', {}))
            accounts.append(account)
    return jsonify({'success': True, 'accounts': accounts, 'categories': CATEGORIES})

@app.route('/api/accounts/<int:account_id>')
def get_account_detail(account_id):
    for key, data in ea_accounts.items():
        if data['id'] == account_id:
            return jsonify({'success': True, 'account': data})
    return jsonify({'success': False, 'error': 'Not found'}), 404

@app.route('/api/accounts/<int:account_id>/trades')
def get_trades(account_id):
    for key, data in ea_accounts.items():
        if data['id'] == account_id:
            return jsonify({'success': True, 'trades': data.get('trades', [])})
    return jsonify({'success': False, 'error': 'Not found'}), 404

@app.route('/api/accounts/<int:account_id>', methods=['PUT'])
def update_account(account_id):
    updates = request.json
    for key, data in ea_accounts.items():
        if data['id'] == account_id:
            if 'name' in updates:
                data['name'] = updates['name']
            if 'category' in updates:
                data['category'] = updates['category']
            save_data()
            return jsonify({'success': True, 'account': data})
    return jsonify({'success': False, 'error': 'Not found'}), 404

@app.route('/api/accounts/<int:account_id>', methods=['DELETE'])
def delete_account(account_id):
    for key, data in ea_accounts.items():
        if data['id'] == account_id:
            data['status'] = 'archived'
            save_data()
            return jsonify({'success': True})
    return jsonify({'success': False, 'error': 'Not found'}), 404

@app.route('/api/webhook/trade', methods=['POST'])
def webhook_trade():
    try:
        data = request.json
        
        # Verify secret
        config = load_config()
        secret = config.get('webhook_secret', '')
        if secret and data.get('secret') != secret:
            logger.warning("Invalid secret in webhook")
            return jsonify({'success': False, 'error': 'Invalid secret'}), 401
        
        # Extract data
        account_num = data.get('account_number')
        ea_name = data.get('ea_name', 'Unknown EA')
        category = data.get('category', 'live')
        trade = data.get('trade')
        
        if not account_num or not trade:
            return jsonify({'success': False, 'error': 'Missing data'}), 400
        
        # Get or create account
        acc_key = get_account_key(account_num, ea_name)
        
        if acc_key not in ea_accounts:
            # Auto-create new account
            new_id = max([a['id'] for a in ea_accounts.values()], default=0) + 1
            ea_accounts[acc_key] = {
                'id': new_id,
                'name': ea_name,
                'account_number': account_num,
                'category': category,
                'platform': data.get('platform', 'MT4'),
                'broker': data.get('broker', 'Unknown'),
                'status': 'active',
                'trades': [],
                'created_at': datetime.now().isoformat()
            }
            logger.info(f"Auto-created account: {ea_name} ({account_num})")
        
        # Add trade
        account = ea_accounts[acc_key]
        trade_id = trade.get('trade_id', str(len(account['trades']) + 1))
        
        # Check duplicate
        if not any(t.get('trade_id') == trade_id for t in account['trades']):
            account['trades'].insert(0, trade)  # Latest first
            account['last_update'] = datetime.now().isoformat()
            
            # Recalculate stats
            account['stats'] = calculate_stats(account['trades'])
            
            save_data()
            logger.info(f"Trade added to {ea_name}: {trade_id}")
        
        return jsonify({'success': True, 'account_id': account['id']})
        
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/categories')
def get_categories():
    return jsonify({'success': True, 'categories': CATEGORIES})

@app.route('/api/status')
def get_status():
    active = sum(1 for a in ea_accounts.values() if a.get('status') != 'archived')
    return jsonify({
        'success': True,
        'status': {
            'accounts_count': active,
            'total_accounts': len(ea_accounts),
            'last_check': datetime.now().isoformat(),
            'version': '2.0.0'
        }
    })

def init_demo_data():
    """Initialize with demo data if no accounts exist"""
    if not ea_accounts:
        logger.info("Initializing demo data")
        from random import random, choice, randint
        
        demo_eas = [
            {'name': 'Waka Waka EA', 'category': 'demo', 'account': 12345678},
            {'name': 'Gold Scalper', 'category': 'live', 'account': 87654321},
            {'name': 'FTMO Challenge Bot', 'category': 'challenge', 'account': 11111111}
        ]
        
        for idx, ea_info in enumerate(demo_eas):
            trades = []
            balance = 2500
            
            for i in range(50):
                is_win = random() > 0.40
                profit = randint(50, 300) if is_win else -randint(30, 250)
                balance += profit
                
                close_time = datetime.now() - timedelta(hours=randint(1, 300))
                trades.append({
                    'trade_id': f'demo_{ea_info["account"]}_{i}',
                    'open_time': (close_time - timedelta(hours=randint(1, 48))).isoformat(),
                    'close_time': close_time.isoformat(),
                    'symbol': choice(['EURUSD', 'GBPUSD', 'XAUUSD', 'BTCUSD']),
                    'type': choice(['BUY', 'SELL']),
                    'lots': round(random() * 0.5 + 0.1, 2),
                    'open_price': round(random() + 1, 5),
                    'close_price': round(random() + 1, 5),
                    'profit': round(profit, 2),
                    'commission': round(-random() * 5, 2),
                    'swap': round((random() - 0.5) * 4, 2),
                    'balance': round(balance, 2)
                })
            
            acc_key = get_account_key(ea_info['account'], ea_info['name'])
            ea_accounts[acc_key] = {
                'id': idx + 1,
                'name': ea_info['name'],
                'account_number': ea_info['account'],
                'category': ea_info['category'],
                'platform': 'MT4',
                'broker': 'Demo Broker',
                'status': 'active',
                'trades': sorted(trades, key=lambda x: x['close_time'], reverse=True),
                'stats': calculate_stats(trades),
                'created_at': datetime.now().isoformat(),
                'last_update': datetime.now().isoformat()
            }
        
        save_data()
        logger.info("Demo data initialized")

if __name__ == '__main__':
    try:
        logger.info("EA Trading Dashboard v2.0 starting...")
        load_data()
        init_demo_data()
        
        port = int(os.getenv('PORT', 8099))
        logger.info(f"Starting on port {port}")
        logger.info("Webhook endpoint: /api/webhook/trade")
        app.run(host='0.0.0.0', port=port, debug=False)
        
    except Exception as e:
        logger.error(f"Startup failed: {e}")
        raise
