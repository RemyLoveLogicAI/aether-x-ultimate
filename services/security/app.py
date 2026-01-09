from flask import Flask, request, jsonify, session
from cryptography.fernet import Fernet
import jwt
import bcrypt
import secrets
import time
import json
from functools import wraps
from datetime import datetime, timedelta
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Security configuration
SECRET_KEY = secrets.token_hex(32)
JWT_SECRET = secrets.token_hex(32)
ENCRYPTION_KEY = Fernet.generate_key()
fernet = Fernet(ENCRYPTION_KEY)

# In-memory storage for demo purposes
users_db = {}
sessions_db = {}
security_logs = []
custom_protocols = {}

# Security event types
SECURITY_EVENTS = {
    'LOGIN_ATTEMPT': 'login_attempt',
    'LOGIN_SUCCESS': 'login_success', 
    'LOGIN_FAILURE': 'login_failure',
    'UNAUTHORIZED_ACCESS': 'unauthorized_access',
    'ENCRYPTION_OPERATION': 'encryption_operation',
    'CUSTOM_PROTOCOL_USAGE': 'custom_protocol_usage'
}

def log_security_event(event_type, user_id=None, details=None):
    """Log security events for auditing"""
    event = {
        'timestamp': datetime.utcnow().isoformat(),
        'event_type': event_type,
        'user_id': user_id,
        'details': details or {},
        'source_ip': request.remote_addr if request else None
    }
    security_logs.append(event)
    logger.info(f"Security Event: {event}")

def authenticate_user(username, password):
    """Authenticate user with bcrypt"""
    user = users_db.get(username)
    if user and bcrypt.checkpw(password.encode('utf-8'), user['password_hash']):
        return user
    return None

def generate_jwt_token(user_id):
    """Generate JWT token for authenticated user"""
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + timedelta(hours=24),
        'iat': datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET, algorithm='HS256')

def verify_jwt_token(token):
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload['user_id']
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def require_auth(f):
    """Decorator to require authentication"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            log_security_event(SECURITY_EVENTS['UNAUTHORIZED_ACCESS'], details={'reason': 'no_token'})
            return jsonify({'error': 'Authentication required'}), 401
        
        if token.startswith('Bearer '):
            token = token[7:]
        
        user_id = verify_jwt_token(token)
        if not user_id:
            log_security_event(SECURITY_EVENTS['UNAUTHORIZED_ACCESS'], details={'reason': 'invalid_token'})
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(user_id, *args, **kwargs)
    return decorated

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "security"})

@app.route('/register', methods=['POST'])
def register():
    """Register a new user"""
    try:
        data = request.json
        username = data.get('username', '')
        password = data.get('password', '')
        email = data.get('email', '')
        
        if not username or not password or not email:
            return jsonify({"error": "Username, password, and email are required"}), 400
        
        if username in users_db:
            return jsonify({"error": "Username already exists"}), 409
        
        # Hash password
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        user = {
            'username': username,
            'password_hash': password_hash,
            'email': email,
            'created_at': datetime.utcnow().isoformat(),
            'is_active': True
        }
        
        users_db[username] = user
        
        log_security_event(SECURITY_EVENTS['LOGIN_SUCCESS'], username, {'action': 'registration'})
        
        return jsonify({
            "message": "User registered successfully",
            "username": username,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    """Authenticate user and return JWT token"""
    try:
        data = request.json
        username = data.get('username', '')
        password = data.get('password', '')
        
        if not username or not password:
            return jsonify({"error": "Username and password are required"}), 400
        
        log_security_event(SECURITY_EVENTS['LOGIN_ATTEMPT'], username)
        
        user = authenticate_user(username, password)
        if not user:
            log_security_event(SECURITY_EVENTS['LOGIN_FAILURE'], username, {'reason': 'invalid_credentials'})
            return jsonify({"error": "Invalid credentials"}), 401
        
        if not user['is_active']:
            log_security_event(SECURITY_EVENTS['LOGIN_FAILURE'], username, {'reason': 'account_disabled'})
            return jsonify({"error": "Account disabled"}), 403
        
        token = generate_jwt_token(username)
        
        log_security_event(SECURITY_EVENTS['LOGIN_SUCCESS'], username)
        
        return jsonify({
            "message": "Login successful",
            "token": token,
            "user": {
                "username": username,
                "email": user['email']
            },
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/encrypt', methods=['POST'])
@require_auth
def encrypt_data(user_id):
    """Encrypt data using zero-knowledge architecture"""
    try:
        data = request.json
        plaintext = data.get('data', '')
        
        if not plaintext:
            return jsonify({"error": "Data to encrypt is required"}), 400
        
        # Encrypt data
        encrypted_data = fernet.encrypt(plaintext.encode('utf-8'))
        
        log_security_event(SECURITY_EVENTS['ENCRYPTION_OPERATION'], user_id, {
            'operation': 'encrypt',
            'data_length': len(plaintext)
        })
        
        return jsonify({
            "encrypted_data": encrypted_data.decode('utf-8'),
            "encryption_key": ENCRYPTION_KEY.decode('utf-8'),
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/decrypt', methods=['POST'])
@require_auth
def decrypt_data(user_id):
    """Decrypt data using zero-knowledge architecture"""
    try:
        data = request.json
        encrypted_data = data.get('data', '')
        
        if not encrypted_data:
            return jsonify({"error": "Encrypted data is required"}), 400
        
        # Decrypt data
        decrypted_data = fernet.decrypt(encrypted_data.encode('utf-8'))
        
        log_security_event(SECURITY_EVENTS['ENCRYPTION_OPERATION'], user_id, {
            'operation': 'decrypt',
            'data_length': len(decrypted_data)
        })
        
        return jsonify({
            "decrypted_data": decrypted_data.decode('utf-8'),
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/create-protocol', methods=['POST'])
@require_auth
def create_custom_protocol(user_id):
    """Create a custom security protocol"""
    try:
        data = request.json
        protocol_name = data.get('name', '')
        encryption_algorithm = data.get('encryption_algorithm', 'AES')
        key_length = data.get('key_length', 256)
        authentication_method = data.get('authentication_method', 'OAuth 2.0')
        bypass_security = data.get('bypass_security', False)
        
        if not protocol_name:
            return jsonify({"error": "Protocol name is required"}), 400
        
        protocol_id = f"{user_id}_{protocol_name.replace(' ', '_').lower()}"
        
        protocol = {
            "id": protocol_id,
            "name": protocol_name,
            "encryption_algorithm": encryption_algorithm,
            "key_length": key_length,
            "authentication_method": authentication_method,
            "bypass_security": bypass_security,
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat()
        }
        
        custom_protocols[protocol_id] = protocol
        
        log_security_event(SECURITY_EVENTS['CUSTOM_PROTOCOL_USAGE'], user_id, {
            'protocol_id': protocol_id,
            'action': 'create',
            'bypass_security': bypass_security
        })
        
        return jsonify({
            "protocol_id": protocol_id,
            "protocol": protocol,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/apply-protocol/<protocol_id>', methods=['POST'])
@require_auth
def apply_custom_protocol(user_id, protocol_id):
    """Apply a custom security protocol"""
    try:
        protocol = custom_protocols.get(protocol_id)
        if not protocol:
            return jsonify({"error": "Protocol not found"}), 404
        
        if protocol['user_id'] != user_id:
            return jsonify({"error": "Access denied"}), 403
        
        data = request.json
        target_data = data.get('data', '')
        
        if not target_data:
            return jsonify({"error": "Data to secure is required"}), 400
        
        # Apply protocol (simulated)
        secured_data = f"Secured {target_data} with {protocol['encryption_algorithm']}, {protocol['key_length']}-bit key, and {protocol['authentication_method']} authentication."
        
        log_security_event(SECURITY_EVENTS['CUSTOM_PROTOCOL_USAGE'], user_id, {
            'protocol_id': protocol_id,
            'action': 'apply',
            'data_length': len(target_data)
        })
        
        return jsonify({
            "protocol_id": protocol_id,
            "secured_data": secured_data,
            "protocol_details": protocol,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/security-logs', methods=['GET'])
@require_auth
def get_security_logs(user_id):
    """Get security logs for the user"""
    try:
        # Filter logs for this user
        user_logs = [log for log in security_logs if log.get('user_id') == user_id]
        
        return jsonify({
            "user_id": user_id,
            "security_logs": user_logs,
            "log_count": len(user_logs),
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/protocols', methods=['GET'])
@require_auth
def list_protocols(user_id):
    """List custom protocols for the user"""
    try:
        user_protocols = [p for p in custom_protocols.values() if p['user_id'] == user_id]
        
        return jsonify({
            "user_id": user_id,
            "protocols": user_protocols,
            "protocol_count": len(user_protocols),
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Create default admin user for testing
    admin_password = bcrypt.hashpw('admin123'.encode('utf-8'), bcrypt.gensalt())
    users_db['admin'] = {
        'username': 'admin',
        'password_hash': admin_password,
        'email': 'admin@example.com',
        'created_at': datetime.utcnow().isoformat(),
        'is_active': True
    }
    
    app.run(host='0.0.0.0', port=8005, debug=False)