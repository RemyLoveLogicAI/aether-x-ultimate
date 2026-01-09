from flask import Flask, request, jsonify
import json
import time
from datetime import datetime
import threading
import queue

app = Flask(__name__)

# In-memory storage for demonstration
data_queue = queue.Queue()
processed_data = []
stream_processors = {}

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "data-processing"})

@app.route('/ingest', methods=['POST'])
def ingest_data():
    """Ingest data for processing"""
    try:
        data = request.json
        data_type = data.get('type', 'generic')
        payload = data.get('data', {})
        
        if not payload:
            return jsonify({"error": "Data payload is required"}), 400
        
        # Add to processing queue
        message = {
            'id': f"msg_{int(time.time() * 1000)}",
            'type': data_type,
            'data': payload,
            'timestamp': datetime.utcnow().isoformat(),
            'source': request.remote_addr
        }
        
        data_queue.put(message)
        
        return jsonify({
            "message_id": message['id'],
            "status": "ingested",
            "queue_size": data_queue.qsize()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stream/process', methods=['POST'])
def start_stream_processing():
    """Start a stream processing job"""
    try:
        data = request.json
        processor_id = data.get('processor_id', f"processor_{int(time.time())}")
        config = data.get('config', {})
        
        if processor_id in stream_processors:
            return jsonify({"error": f"Processor {processor_id} already exists"}), 409
        
        # Start processing thread
        processor_thread = threading.Thread(
            target=process_stream,
            args=(processor_id, config),
            daemon=True
        )
        processor_thread.start()
        
        stream_processors[processor_id] = {
            'thread': processor_thread,
            'status': 'running',
            'config': config,
            'processed_count': 0,
            'start_time': datetime.utcnow().isoformat()
        }
        
        return jsonify({
            "processor_id": processor_id,
            "status": "started",
            "config": config
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stream/stop/<processor_id>', methods=['POST'])
def stop_stream_processing(processor_id):
    """Stop a stream processing job"""
    try:
        if processor_id not in stream_processors:
            return jsonify({"error": f"Processor {processor_id} not found"}), 404
        
        stream_processors[processor_id]['status'] = 'stopped'
        
        return jsonify({
            "processor_id": processor_id,
            "status": "stopped"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stream/status', methods=['GET'])
def get_stream_status():
    """Get status of all stream processors"""
    try:
        return jsonify({
            "processors": stream_processors,
            "queue_size": data_queue.qsize(),
            "processed_count": len(processed_data)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stream/results', methods=['GET'])
def get_stream_results():
    """Get processed results"""
    try:
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        results = processed_data[offset:offset + limit]
        
        return jsonify({
            "results": results,
            "total": len(processed_data),
            "limit": limit,
            "offset": offset
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/etl/pipeline', methods=['POST'])
def create_etl_pipeline():
    """Create an ETL pipeline"""
    try:
        data = request.json
        pipeline_id = data.get('pipeline_id', f"pipeline_{int(time.time())}")
        steps = data.get('steps', [])
        
        if not steps:
            return jsonify({"error": "ETL steps are required"}), 400
        
        # Execute ETL pipeline synchronously for demo
        result = execute_etl_pipeline(steps)
        
        return jsonify({
            "pipeline_id": pipeline_id,
            "status": "completed",
            "result": result
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/transform', methods=['POST'])
def transform_data():
    """Transform data using various techniques"""
    try:
        data = request.json
        input_data = data.get('data', {})
        transformation_type = data.get('type', 'normalize')
        
        if not input_data:
            return jsonify({"error": "Input data is required"}), 400
        
        transformed_data = apply_transformation(input_data, transformation_type)
        
        return jsonify({
            "transformation_type": transformation_type,
            "input_data": input_data,
            "transformed_data": transformed_data,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def process_stream(processor_id, config):
    """Process data stream in background"""
    while True:
        try:
            # Check if processor should stop
            if stream_processors.get(processor_id, {}).get('status') == 'stopped':
                break
            
            # Get data from queue
            if not data_queue.empty():
                message = data_queue.get(timeout=1)
                
                # Process the message
                processed_message = {
                    'original_id': message['id'],
                    'processor_id': processor_id,
                    'processed_data': apply_stream_processing(message['data'], config),
                    'processed_at': datetime.utcnow().isoformat()
                }
                
                # Store result
                processed_data.append(processed_message)
                
                # Update counter
                if processor_id in stream_processors:
                    stream_processors[processor_id]['processed_count'] += 1
                
                data_queue.task_done()
            else:
                time.sleep(0.1)  # Small delay to prevent busy waiting
                
        except queue.Empty:
            time.sleep(0.1)
        except Exception as e:
            print(f"Error in stream processor {processor_id}: {e}")
            time.sleep(1)

def execute_etl_pipeline(steps):
    """Execute ETL pipeline steps"""
    result = {}
    
    for step in steps:
        step_type = step.get('type', '')
        step_config = step.get('config', {})
        
        if step_type == 'extract':
            result = extract_data(step_config)
        elif step_type == 'transform':
            result = transform_data_step(result, step_config)
        elif step_type == 'load':
            result = load_data(result, step_config)
        else:
            raise ValueError(f"Unknown ETL step type: {step_type}")
    
    return result

def extract_data(config):
    """Extract data from various sources"""
    source_type = config.get('source_type', 'api')
    
    if source_type == 'api':
        # Simulate API call
        return {
            "source": "api",
            "data": {"users": [{"id": 1, "name": "John"}, {"id": 2, "name": "Jane"}]}
        }
    elif source_type == 'database':
        # Simulate database query
        return {
            "source": "database", 
            "data": {"orders": [{"id": 1, "amount": 100}, {"id": 2, "amount": 200}]}
        }
    else:
        return {"source": source_type, "data": {}}

def transform_data_step(data, config):
    """Transform extracted data"""
    transform_type = config.get('transform_type', 'filter')
    
    if transform_type == 'filter':
        # Simple filter transformation
        filtered_data = {k: v for k, v in data.items() if k != 'sensitive_data'}
        return filtered_data
    elif transform_type == 'aggregate':
        # Simple aggregation
        if isinstance(data, dict) and 'data' in data:
            items = data['data']
            if isinstance(items, list):
                total = sum(item.get('amount', 0) for item in items)
                return {"aggregated_total": total, "count": len(items)}
        return data
    else:
        return data

def load_data(data, config):
    """Load transformed data to destination"""
    destination_type = config.get('destination_type', 'memory')
    
    if destination_type == 'memory':
        # Store in memory
        processed_data.append({
            'loaded_data': data,
            'loaded_at': datetime.utcnow().isoformat(),
            'destination': 'memory'
        })
        return {"status": "loaded", "destination": "memory"}
    else:
        return {"status": "completed", "destination": destination_type}

def apply_stream_processing(data, config):
    """Apply stream processing logic"""
    # Simple stream processing simulation
    processed = {
        'original_data': data,
        'processing_config': config,
        'timestamp': datetime.utcnow().isoformat(),
        'processed': True
    }
    
    # Add some stream-specific processing based on config
    if config.get('enrich_data', False):
        processed['enriched_data'] = {
            'source_ip': '127.0.0.1',  # Simulated enrichment
            'user_agent': 'Aether-X Ultimate'
        }
    
    return processed

def apply_transformation(data, transformation_type):
    """Apply data transformation"""
    if transformation_type == 'normalize':
        # Normalize numerical values
        normalized = {}
        for key, value in data.items():
            if isinstance(value, (int, float)):
                normalized[key] = value / 100.0 if value > 0 else 0
            else:
                normalized[key] = value
        return normalized
    
    elif transformation_type == 'encode':
        # Simple encoding simulation
        return {
            'encoded_data': str(data),
            'encoding_type': 'base64_simulation'
        }
    
    elif transformation_type == 'filter':
        # Filter sensitive data
        return {k: v for k, v in data.items() if not k.startswith('password')}
    
    else:
        return data

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8006, debug=False)