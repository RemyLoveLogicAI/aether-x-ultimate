from flask import Flask, request, jsonify
import requests
import time
import logging
from functools import wraps
from datetime import datetime

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Service endpoints
SERVICES = {
    'text-generation': 'http://text-generation-service:8000',
    'image-generation': 'http://image-generation-service:8001',
    'video-generation': 'http://video-generation-service:8002',
    'ai-models': 'http://ai-models-service:8003',
    'no-code-development': 'http://no-code-development-service:8004',
    'security': 'http://security-service:8005',
    'data-processing': 'http://data-processing-service:8006'
}

# Rate limiting storage
rate_limits = {}

def rate_limit(max_requests=100, window_seconds=60):
    """Simple rate limiting decorator"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            client_ip = request.remote_addr
            
            if client_ip not in rate_limits:
                rate_limits[client_ip] = []
            
            # Clean old requests
            now = time.time()
            rate_limits[client_ip] = [req_time for req_time in rate_limits[client_ip] if now - req_time < window_seconds]
            
            # Check rate limit
            if len(rate_limits[client_ip]) >= max_requests:
                return jsonify({"error": "Rate limit exceeded"}), 429
            
            # Add current request
            rate_limits[client_ip].append(now)
            
            return f(*args, **kwargs)
        return decorated
    return decorator

def log_request(f):
    """Log incoming requests"""
    @wraps(f)
    def decorated(*args, **kwargs):
        start_time = time.time()
        
        try:
            result = f(*args, **kwargs)
            status_code = result[1] if isinstance(result, tuple) else 200
        except Exception as e:
            status_code = 500
            result = jsonify({"error": str(e)})
        
        duration = time.time() - start_time
        
        logger.info(f"Request: {request.method} {request.path} - IP: {request.remote_addr} - Status: {status_code} - Duration: {duration:.3f}s")
        
        return result
    return decorated

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "api-gateway"})

@app.route('/api/<service>/<path:endpoint>', methods=['GET', 'POST', 'PUT', 'DELETE'])
@rate_limit(max_requests=200, window_seconds=60)
@log_request
def proxy_request(service, endpoint):
    """Proxy requests to microservices"""
    if service not in SERVICES:
        return jsonify({"error": f"Service '{service}' not found"}), 404
    
    service_url = f"{SERVICES[service]}/{endpoint}"
    
    try:
        # Forward headers
        headers = {key: value for key, value in request.headers if key.lower() != 'host'}
        
        # Forward request to service
        if request.method == 'GET':
            response = requests.get(service_url, params=request.args, headers=headers)
        elif request.method == 'POST':
            response = requests.post(service_url, json=request.json, headers=headers)
        elif request.method == 'PUT':
            response = requests.put(service_url, json=request.json, headers=headers)
        elif request.method == 'DELETE':
            response = requests.delete(service_url, headers=headers)
        else:
            return jsonify({"error": "Method not allowed"}), 405
        
        # Return response
        return jsonify(response.json()), response.status_code
        
    except requests.exceptions.ConnectionError:
        return jsonify({"error": f"Service '{service}' is unavailable"}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Service-specific API endpoints

@app.route('/api/v1/text/generate', methods=['POST'])
@rate_limit(max_requests=100, window_seconds=60)
@log_request
def generate_text():
    """Generate text using the text generation service"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['text-generation']}/generate", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/image/generate', methods=['POST'])
@rate_limit(max_requests=50, window_seconds=60)
@log_request
def generate_image():
    """Generate image using the image generation service"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['image-generation']}/generate", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/video/generate', methods=['POST'])
@rate_limit(max_requests=20, window_seconds=60)
@log_request
def generate_video():
    """Generate video using the video generation service"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['video-generation']}/generate", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/llm/generate', methods=['POST'])
@rate_limit(max_requests=100, window_seconds=60)
@log_request
def generate_llm():
    """Generate text using large language models"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['ai-models']}/llm/generate", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/app/create', methods=['POST'])
@rate_limit(max_requests=100, window_seconds=60)
@log_request
def create_app():
    """Create a new no-code app"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['no-code-development']}/create-app", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/workflow/create', methods=['POST'])
@rate_limit(max_requests=100, window_seconds=60)
@log_request
def create_workflow():
    """Create a new workflow"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['no-code-development']}/create-workflow", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/user/register', methods=['POST'])
@rate_limit(max_requests=50, window_seconds=60)
@log_request
def register_user():
    """Register a new user"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['security']}/register", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/user/login', methods=['POST'])
@rate_limit(max_requests=50, window_seconds=60)
@log_request
def login_user():
    """Authenticate user and return JWT token"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['security']}/login", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/data/ingest', methods=['POST'])
@rate_limit(max_requests=200, window_seconds=60)
@log_request
def ingest_data():
    """Ingest data for processing"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['data-processing']}/ingest", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/data/stream/start', methods=['POST'])
@rate_limit(max_requests=50, window_seconds=60)
@log_request
def start_stream_processing():
    """Start stream processing"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['data-processing']}/stream/process", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/encrypt', methods=['POST'])
@rate_limit(max_requests=100, window_seconds=60)
@log_request
def encrypt_data():
    """Encrypt data using security service"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['security']}/encrypt", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/decrypt', methods=['POST'])
@rate_limit(max_requests=100, window_seconds=60)
@log_request
def decrypt_data():
    """Decrypt data using security service"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['security']}/decrypt", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/protocol/create', methods=['POST'])
@rate_limit(max_requests=50, window_seconds=60)
@log_request
def create_protocol():
    """Create a custom security protocol"""
    try:
        data = request.json
        response = requests.post(f"{SERVICES['security']}/create-protocol", json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/metrics', methods=['GET'])
@log_request
def get_metrics():
    """Get gateway metrics"""
    try:
        return jsonify({
            "service": "api-gateway",
            "timestamp": datetime.utcnow().isoformat(),
            "rate_limits": {
                "active_clients": len(rate_limits),
                "total_requests": sum(len(requests) for requests in rate_limits.values())
            },
            "services": SERVICES
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)