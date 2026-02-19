#!/usr/bin/env python3
"""EA Trading Dashboard v4.12.0.2 - Table settings, sortable columns, manual deposits"""
import os, json, logging
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import requests

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50 MB for large trade histories
CORS(app)

# Configure logging based on LOG_LEVEL env var
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'normal').lower()
if LOG_LEVEL == 'debug':
    logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
else:
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

DATA_FILE = '/data/ea_data.json'

def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                data = json.load(f)
                if 'accounts' not in data:
                    data['accounts'] = []
                if 'settings' not in data:
                    data['settings'] = {'display_currency': 'USD'}
                return data
        except Exception as e:
            logger.error(f'Error loading: {e}')
    return {'accounts': [], 'settings': {'display_currency': 'USD'}}

def save_data(data):
    try:
        with open(DATA_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        logger.error(f'Save error: {e}')

def parse_date(date_str):
    try:
        if '.' in date_str and ':' in date_str and 'T' not in date_str:
            date_str = date_str.replace('.', '-').replace(' ', 'T')
        return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
    except:
        return None

@app.route('/')
def index():
    return send_file('static/index.html')

@app.route('/api/accounts')
def get_accounts():
    data = load_data()
    accounts_summary = []
    total_balance = 0
    total_profit = 0
    total_trades_count = 0
    
    for acc in data['accounts']:
        if acc.get('status') == 'deleted':
            continue
        
        trades = acc.get('trades', [])
        open_trades = acc.get('open_trades', [])
        
        closed_profit = sum(t.get('profit', 0) for t in trades)
        open_profit = sum(t.get('profit', 0) for t in open_trades)
        total_profit_acc = closed_profit + open_profit
        
        winning_trades = [t for t in trades if t.get('profit', 0) > 0]
        losing_trades = [t for t in trades if t.get('profit', 0) < 0]
        
        win_rate = (len(winning_trades) / len(trades) * 100) if trades else 0
        gross_profit = sum(t['profit'] for t in winning_trades) if winning_trades else 0
        gross_loss = abs(sum(t['profit'] for t in losing_trades)) if losing_trades else 0
        profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else 0
        
        # Total deposit = manual (user-set) + auto (MT-detected)
        manual_dep = acc.get('manual_deposit', 0)
        auto_dep = acc.get('auto_deposits', 0)
        # Fallback for old accounts without new fields
        if manual_dep == 0 and auto_dep == 0:
            manual_dep = acc.get('deposit', 0) or acc.get('initial_balance', 0) or acc.get('total_deposits', 0)
        deposit = manual_dep + auto_dep
        if deposit == 0:
            deposit = 1000  # prevent division by zero
        
        # CORRECT Drawdown: track lowest point from peak
        peak = deposit
        lowest_point = deposit
        max_dd = 0
        sorted_trades = sorted(trades, key=lambda x: x.get('close_time', ''))
        running_balance = deposit
        
        for trade in sorted_trades:
            running_balance += trade.get('profit', 0)
            
            # Update peak
            if running_balance > peak:
                peak = running_balance
                lowest_point = running_balance
            
            # Track lowest from peak
            if running_balance < lowest_point:
                lowest_point = running_balance
            
            # DD = (peak - lowest) / peak
            if peak > 0:
                dd = ((peak - lowest_point) / peak * 100)
                if dd > max_dd:
                    max_dd = dd
        
        days = 0
        if trades:
            first_trade = min(trades, key=lambda x: x.get('open_time', ''))
            first_date = parse_date(first_trade.get('open_time', ''))
            if first_date:
                days = (datetime.now() - first_date).days
        
        gain_percent = ((total_profit_acc / deposit) * 100) if deposit > 0 else 0
        current_balance = acc.get('current_balance', 0)
        
        # Only count live/copy in overview totals (never demo)
        cat = acc.get('category', 'live')
        if cat != 'demo':
            total_balance += current_balance
            total_profit += total_profit_acc
            total_trades_count += len(trades)
        
        # Calculate advanced stats (MyFxBook style)
        avg_win = (gross_profit / len(winning_trades)) if winning_trades else 0
        avg_loss = (gross_loss / len(losing_trades)) if losing_trades else 0
        avg_trade_duration = 0
        if trades:
            durations = []
            for t in trades:
                open_dt = parse_date(t.get('open_time', ''))
                close_dt = parse_date(t.get('close_time', ''))
                if open_dt and close_dt:
                    durations.append((close_dt - open_dt).total_seconds() / 3600)
            if durations:
                avg_trade_duration = sum(durations) / len(durations)
        
        best_trade = max([t.get('profit', 0) for t in trades]) if trades else 0
        worst_trade = min([t.get('profit', 0) for t in trades]) if trades else 0
        
        # Online status check
        last_webhook_str = acc.get('last_webhook')
        timeout = acc.get('online_timeout', 60)
        is_online = False
        seconds_since = None
        if last_webhook_str:
            try:
                last_dt = datetime.fromisoformat(last_webhook_str.replace('Z', '+00:00'))
                seconds_since = (datetime.now() - last_dt).total_seconds()
                is_online = seconds_since <= timeout
            except:
                pass
        
        accounts_summary.append({
            'id': acc['id'],
            'name': acc['name'],
            'account_number': acc['account_number'],
            'broker': acc.get('broker', 'Unknown'),
            'platform': acc.get('platform', 'MT4'),
            'category': acc.get('category', 'demo'),
            'type': acc.get('type', 'Live'),
            'currency': acc.get('currency', 'USD'),
            'deposit': deposit,  # Calculated: manual + auto
            'manual_deposit': acc.get('manual_deposit', 0),
            'auto_deposits': acc.get('auto_deposits', 0),
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
            'withdrawals': acc.get('withdrawals', 0),
            'total_deposits': acc.get('total_deposits', 0),
            'total_withdrawals': acc.get('total_withdrawals', 0),
            'leverage': acc.get('leverage', 0),
            'floating_pl': round(open_profit, 2),
            'gain_percent': round(gain_percent, 2),
            'avg_win': round(avg_win, 2),
            'avg_loss': round(avg_loss, 2),
            'avg_trade_duration': round(avg_trade_duration, 2),
            'best_trade': round(best_trade, 2),
            'worst_trade': round(worst_trade, 2),
            'status': acc.get('status', 'active'),
            'last_update': acc.get('last_update', datetime.now().isoformat()),
            'is_online': is_online,
            'last_webhook': last_webhook_str,
            'seconds_since_webhook': int(seconds_since) if seconds_since else None,
            'online_timeout': timeout
        })
    
    return jsonify({
        'success': True,
        'accounts': accounts_summary,
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
        return jsonify({'success': False, 'error': 'Not found'}), 404
    
    trades = account.get('trades', [])
    deposit = account.get('deposit', 1000)
    equity_curve = []
    running_balance = deposit
    
    sorted_trades = sorted(trades, key=lambda x: x.get('close_time', ''))
    for trade in sorted_trades:
        running_balance += trade.get('profit', 0)
        close_date = parse_date(trade.get('close_time', ''))
        if close_date:
            equity_curve.append({
                'date': close_date.isoformat(),
                'balance': round(running_balance, 2),
                'profit': trade.get('profit', 0)
            })
    
    # Symbol breakdown
    symbol_stats = {}
    for t in trades:
        sym = t.get('symbol', 'Unknown')
        if sym not in symbol_stats:
            symbol_stats[sym] = {'count': 0, 'profit': 0, 'wins': 0}
        symbol_stats[sym]['count'] += 1
        symbol_stats[sym]['profit'] += t.get('profit', 0)
        if t.get('profit', 0) > 0:
            symbol_stats[sym]['wins'] += 1
    
    symbols = [{'symbol': k, **v, 'win_rate': round((v['wins']/v['count']*100) if v['count'] > 0 else 0, 2)} 
               for k, v in symbol_stats.items()]
    
    return jsonify({
        'success': True,
        'account': account,
        'equity_curve': equity_curve,
        'symbols': sorted(symbols, key=lambda x: x['count'], reverse=True)
    })

@app.route('/api/live-trades')
def get_live_trades():
    data = load_data()
    live_trades = []
    for acc in data['accounts']:
        if acc.get('status') != 'deleted':
            for trade in acc.get('open_trades', []):
                live_trades.append({**trade, 'account_name': acc['name'], 'account_id': acc['id']})
    
    live_trades_sorted = sorted(live_trades, key=lambda x: x.get('open_time', ''), reverse=True)
    total_pl = sum(t.get('profit', 0) for t in live_trades)
    
    return jsonify({
        'success': True,
        'live_trades': live_trades_sorted[:10],
        'total': len(live_trades_sorted),
        'total_pl': round(total_pl, 2)
    })

@app.route('/api/today-trades')
def get_today_trades():
    data = load_data()
    today = datetime.now().date()
    today_trades = []
    
    for acc in data['accounts']:
        if acc.get('status') != 'deleted':
            for trade in acc.get('trades', []):
                close_date = parse_date(trade.get('close_time', ''))
                if close_date and close_date.date() == today:
                    today_trades.append({**trade, 'account_name': acc['name'], 'account_id': acc['id']})
    
    today_trades_sorted = sorted(today_trades, key=lambda x: x.get('close_time', ''), reverse=True)
    total_pl = sum(t.get('profit', 0) for t in today_trades)
    
    return jsonify({
        'success': True,
        'today_trades': today_trades_sorted[:10],
        'total': len(today_trades_sorted),
        'total_pl': round(total_pl, 2)
    })

@app.route('/api/accounts/<int:account_id>', methods=['PUT'])
def update_account(account_id):
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    if not account:
        return jsonify({'success': False}), 404
    
    updates = request.json
    if 'manual_deposit' in updates:
        account['manual_deposit'] = float(updates['manual_deposit'])
    if 'name' in updates:
        account['name'] = updates['name']
    if 'currency' in updates:
        account['currency'] = updates['currency']
    if 'online_timeout' in updates:
        account['online_timeout'] = int(updates['online_timeout'])
    
    account['last_update'] = datetime.now().isoformat()
    save_data(data)
    return jsonify({'success': True})

@app.route('/api/accounts/<int:account_id>', methods=['DELETE'])
def delete_account(account_id):
    data = load_data()
    account = next((a for a in data['accounts'] if a['id'] == account_id), None)
    if not account:
        return jsonify({'success': False}), 404
    account['status'] = 'deleted'
    save_data(data)
    return jsonify({'success': True})

@app.route('/api/settings', methods=['GET', 'POST'])
def settings():
    data = load_data()
    if request.method == 'POST':
        updates = request.json
        if 'display_currency' in updates:
            data['settings']['display_currency'] = updates['display_currency']
        save_data(data)
    return jsonify({'success': True, 'settings': data['settings']})

@app.route('/api/webhook/batch', methods=['POST'])
def webhook_batch():
    # Catch ALL errors including Flask's 400 Bad Request
    raw_data = None
    if LOG_LEVEL == 'debug':
        try:
            raw_data = request.get_data(as_text=True)
            logger.debug(f'=== WEBHOOK DEBUG START ===')
            logger.debug(f'Content-Type: {request.content_type}')
            logger.debug(f'Content-Length: {request.content_length}')
            logger.debug(f'Raw data length: {len(raw_data)} chars')
            logger.debug(f'Raw data (first 2000 chars):\n{raw_data[:2000]}')
        except Exception as e:
            logger.error(f'Failed to read raw data: {e}')
            return jsonify({'success': False, 'error': 'Cannot read request'}), 400
    
    try:
        logger.info(f'Webhook received from {request.remote_addr}')
        
        try:
            payload = request.json
        except Exception as e:
            logger.error(f'Webhook: JSON parsing failed: {e}')
            logger.error(f'Webhook: First 1000 chars of raw data: {request.data[:1000]}')
            return jsonify({'success': False, 'error': f'JSON parse error: {str(e)}'}), 400
        
        if not payload:
            logger.error('Webhook: No JSON payload')
            logger.error(f'Webhook: Raw data: {request.data[:500]}')  # First 500 bytes
            return jsonify({'success': False, 'error': 'No JSON payload'}), 400
        
        # Log complete payload (only in debug mode)
        if LOG_LEVEL == 'debug':
            logger.debug(f'Webhook: Payload keys: {list(payload.keys())}')
            logger.debug(f'Webhook: account_number={payload.get("account_number")}')
            logger.debug(f'Webhook: ea_name={payload.get("ea_name")}')
            logger.debug(f'Webhook: broker={payload.get("broker")}')
            logger.debug(f'Webhook: category={payload.get("category")}')
            logger.debug(f'Webhook: trades_count={len(payload.get("trades", []))}')
            logger.debug(f'Webhook: open_trades_count={len(payload.get("open_trades", []))}')
            
        account_number = payload.get('account_number')
        ea_name = payload.get('ea_name')
        
        if not account_number or not ea_name:
            logger.error(f'Webhook: Missing required fields!')
            logger.error(f'Webhook: account_number={account_number} (type: {type(account_number)})')
            logger.error(f'Webhook: ea_name={ea_name} (type: {type(ea_name)})')
            logger.error(f'Webhook: Full payload: {payload}')
            return jsonify({'success': False, 'error': 'Missing account_number or ea_name'}), 400
        
        data = load_data()
        # Match ONLY by account_number (more robust than name matching)
        account = next((a for a in data['accounts'] 
                       if a['account_number'] == account_number), None)
        
        if not account:
            new_id = max([a['id'] for a in data['accounts']], default=0) + 1
            account = {
                'id': new_id,
                'account_number': account_number,
                'name': ea_name,
                'broker': payload.get('broker', 'Unknown'),
                'platform': payload.get('platform', 'MT4'),
                'category': payload.get('category', 'demo'),
                'type': 'Live',
                'currency': payload.get('currency', 'USD'),
                'current_balance': payload.get('current_balance', 0),
                'trades': [],
                'open_trades': [],
                'manual_deposit': 0,  # User-set, never overwritten by webhook
                'auto_deposits': payload.get('total_deposits', 0),  # MT4/MT5 detected
                'total_withdrawals': payload.get('total_withdrawals', 0),
                'leverage': payload.get('leverage', 0),
                'withdrawals': 0,
                'online_timeout': 60,  # default timeout in seconds
                'last_webhook': datetime.now().isoformat(),
                'status': 'active',
                'created_at': datetime.now().isoformat(),
                'last_update': datetime.now().isoformat()
            }
            data['accounts'].append(account)
            logger.info(f'Created: {ea_name} ({account_number})')
        elif account.get('status') == 'deleted':
            account['status'] = 'active'
            account['trades'] = []
            account['open_trades'] = []
            logger.info(f'Reactivated: {ea_name}')
        
        # Update account fields from webhook
        # CRITICAL: Preserve user-set fields (manual_deposit, online_timeout)
        account['name'] = ea_name  # Allow name updates
        account['current_balance'] = payload.get('current_balance', account['current_balance'])
        # Update auto_deposits from MT, but NEVER touch manual_deposit or online_timeout
        account['auto_deposits'] = payload.get('total_deposits', account.get('auto_deposits', 0))
        account['total_withdrawals'] = payload.get('total_withdrawals', account.get('total_withdrawals', 0))
        account['leverage'] = payload.get('leverage', account.get('leverage', 0))
        account['last_webhook'] = datetime.now().isoformat()  # Online status tracking
        
        # Initialize missing fields with defaults (for old accounts)
        if 'manual_deposit' not in account:
            account['manual_deposit'] = 0
        if 'online_timeout' not in account:
            account['online_timeout'] = 60
        
        if 'trades' in payload:
            existing_ids = set(t.get('trade_id') for t in account['trades'])
            for trade in payload['trades']:
                trade_id = trade.get('trade_id')
                if trade_id not in existing_ids:
                    account['trades'].append(trade)
                    existing_ids.add(trade_id)
        
        if 'open_trades' in payload:
            account['open_trades'] = payload['open_trades']
        
        account['last_update'] = datetime.now().isoformat()
        save_data(data)
        
        return jsonify({'success': True, 'account_id': account['id']})
    except Exception as e:
        logger.error(f'Webhook error: {e}')
        logger.error(f'Webhook error type: {type(e).__name__}')
        logger.error(f'Webhook error details: {str(e)}')
        if raw_data:
            logger.error(f'Webhook failed with data: {raw_data[:2000]}')
        import traceback
        logger.error(f'Traceback: {traceback.format_exc()}')
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    logger.info('EA Dashboard v4.7.0 starting...')
    app.run(host='0.0.0.0', port=8099, debug=False)
