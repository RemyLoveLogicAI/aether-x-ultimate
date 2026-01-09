from flask import Flask, request, jsonify
import json
import uuid
import yaml
from datetime import datetime

app = Flask(__name__)

# In-memory storage for apps and workflows
apps_store = {}
workflows_store = {}

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "no-code-development"})

@app.route('/create-app', methods=['POST'])
def create_app():
    """Create a new no-code app from description"""
    try:
        data = request.json
        description = data.get('description', '')
        app_name = data.get('name', f"App_{uuid.uuid4().hex[:8]}")
        
        if not description:
            return jsonify({"error": "Description is required"}), 400
        
        # Generate app structure based on description
        app_structure = generate_app_structure(description)
        
        app_id = str(uuid.uuid4())
        app_data = {
            "id": app_id,
            "name": app_name,
            "description": description,
            "structure": app_structure,
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        }
        
        apps_store[app_id] = app_data
        
        return jsonify({
            "app_id": app_id,
            "app_name": app_name,
            "structure": app_structure,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/get-app/<app_id>', methods=['GET'])
def get_app(app_id):
    """Get app details by ID"""
    try:
        app_data = apps_store.get(app_id)
        if not app_data:
            return jsonify({"error": "App not found"}), 404
        
        return jsonify(app_data)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/list-apps', methods=['GET'])
def list_apps():
    """List all created apps"""
    try:
        return jsonify({
            "apps": list(apps_store.values()),
            "count": len(apps_store)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/create-workflow', methods=['POST'])
def create_workflow():
    """Create a new workflow"""
    try:
        data = request.json
        app_id = data.get('app_id', '')
        workflow_description = data.get('description', '')
        workflow_name = data.get('name', f"Workflow_{uuid.uuid4().hex[:8]}")
        
        if not app_id:
            return jsonify({"error": "App ID is required"}), 400
        
        if not workflow_description:
            return jsonify({"error": "Workflow description is required"}), 400
        
        # Generate workflow structure
        workflow_structure = generate_workflow_structure(workflow_description)
        
        workflow_id = str(uuid.uuid4())
        workflow_data = {
            "id": workflow_id,
            "name": workflow_name,
            "app_id": app_id,
            "description": workflow_description,
            "structure": workflow_structure,
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        }
        
        workflows_store[workflow_id] = workflow_data
        
        return jsonify({
            "workflow_id": workflow_id,
            "workflow_name": workflow_name,
            "app_id": app_id,
            "structure": workflow_structure,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/get-workflow/<workflow_id>', methods=['GET'])
def get_workflow(workflow_id):
    """Get workflow details by ID"""
    try:
        workflow_data = workflows_store.get(workflow_id)
        if not workflow_data:
            return jsonify({"error": "Workflow not found"}), 404
        
        return jsonify(workflow_data)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/list-workflows', methods=['GET'])
def list_workflows():
    """List all created workflows"""
    try:
        # Filter by app_id if provided
        app_id = request.args.get('app_id')
        
        workflows = list(workflows_store.values())
        if app_id:
            workflows = [w for w in workflows if w.get('app_id') == app_id]
        
        return jsonify({
            "workflows": workflows,
            "count": len(workflows)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/execute-workflow/<workflow_id>', methods=['POST'])
def execute_workflow(workflow_id):
    """Execute a workflow with provided data"""
    try:
        workflow_data = workflows_store.get(workflow_id)
        if not workflow_data:
            return jsonify({"error": "Workflow not found"}), 404
        
        data = request.json
        input_data = data.get('input_data', {})
        
        # Execute workflow steps
        execution_result = execute_workflow_steps(workflow_data['structure'], input_data)
        
        return jsonify({
            "workflow_id": workflow_id,
            "execution_result": execution_result,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def generate_app_structure(description):
    """Generate app structure based on natural language description"""
    structure = {
        "pages": [],
        "components": [],
        "data_sources": [],
        "events": []
    }
    
    # Simple keyword-based parsing for demo
    description_lower = description.lower()
    
    if "social media" in description_lower:
        structure["pages"] = [
            {"id": "dashboard", "name": "Dashboard", "type": "dashboard"},
            {"id": "posts", "name": "Posts", "type": "list"},
            {"id": "analytics", "name": "Analytics", "type": "chart"}
        ]
        structure["components"] = [
            {"type": "button", "text": "Create Post"},
            {"type": "input", "placeholder": "Search posts"},
            {"type": "chart", "type": "bar"}
        ]
    
    elif "e-commerce" in description_lower:
        structure["pages"] = [
            {"id": "home", "name": "Home", "type": "landing"},
            {"id": "products", "name": "Products", "type": "grid"},
            {"id": "cart", "name": "Cart", "type": "form"}
        ]
        structure["components"] = [
            {"type": "button", "text": "Add to Cart"},
            {"type": "input", "placeholder": "Search products"},
            {"type": "image-gallery"}
        ]
    
    else:
        # Generic app structure
        structure["pages"] = [
            {"id": "main", "name": "Main", "type": "form"},
            {"id": "list", "name": "List", "type": "list"}
        ]
        structure["components"] = [
            {"type": "button", "text": "Submit"},
            {"type": "input", "placeholder": "Enter text"},
            {"type": "text-display"}
        ]
    
    # Add data sources
    structure["data_sources"] = [
        {"id": "local_storage", "type": "local", "name": "Local Storage"},
        {"id": "api", "type": "rest", "url": "https://api.example.com/data"}
    ]
    
    return structure

def generate_workflow_structure(description):
    """Generate workflow structure based on description"""
    steps = []
    
    description_lower = description.lower()
    
    if "social media" in description_lower and "influence" in description_lower:
        steps = [
            {
                "id": "1",
                "type": "api_call",
                "name": "Fetch Social Media Data",
                "config": {
                    "method": "GET",
                    "url": "https://api.socialmedia.com/posts",
                    "params": {"limit": 100}
                }
            },
            {
                "id": "2",
                "type": "data_processing",
                "name": "Analyze Engagement",
                "config": {
                    "algorithm": "engagement_score",
                    "threshold": 0.8
                }
            },
            {
                "id": "3",
                "type": "content_generation",
                "name": "Generate Targeted Content",
                "config": {
                    "model": "text_generation",
                    "prompt": "Create engaging content about {topic}"
                }
            },
            {
                "id": "4",
                "type": "api_call",
                "name": "Post to Platforms",
                "config": {
                    "method": "POST",
                    "url": "https://api.socialmedia.com/posts",
                    "data_source": "generated_content"
                }
            }
        ]
    
    elif "automation" in description_lower:
        steps = [
            {
                "id": "1",
                "type": "data_fetch",
                "name": "Fetch Data",
                "config": {
                    "source": "database",
                    "query": "SELECT * FROM users WHERE active = true"
                }
            },
            {
                "id": "2",
                "type": "data_processing",
                "name": "Process Data",
                "config": {
                    "operation": "filter",
                    "criteria": "age > 18"
                }
            },
            {
                "id": "3",
                "type": "notification",
                "name": "Send Notifications",
                "config": {
                    "method": "email",
                    "template": "user_notification"
                }
            }
        ]
    
    else:
        # Generic workflow
        steps = [
            {
                "id": "1",
                "type": "input",
                "name": "Get Input",
                "config": {
                    "type": "form",
                    "fields": ["name", "email"]
                }
            },
            {
                "id": "2",
                "type": "process",
                "name": "Process Data",
                "config": {
                    "operation": "validate"
                }
            },
            {
                "id": "3",
                "type": "output",
                "name": "Generate Output",
                "config": {
                    "format": "json"
                }
            }
        ]
    
    return {
        "steps": steps,
        "triggers": ["manual", "scheduled"],
        "conditions": []
    }

def execute_workflow_steps(structure, input_data):
    """Execute workflow steps with provided input data"""
    results = []
    
    for step in structure.get("steps", []):
        step_result = {
            "step_id": step["id"],
            "step_name": step["name"],
            "status": "success",
            "output": None
        }
        
        try:
            if step["type"] == "api_call":
                # Simulate API call
                step_result["output"] = {
                    "status": "completed",
                    "data": f"API response for {step['name']}"
                }
            
            elif step["type"] == "data_processing":
                # Simulate data processing
                step_result["output"] = {
                    "processed_data": f"Processed data for {step['name']}",
                    "metrics": {"records_processed": 100}
                }
            
            elif step["type"] == "content_generation":
                # Simulate content generation
                step_result["output"] = {
                    "generated_content": f"Generated content for {step['name']}",
                    "content_type": "text"
                }
            
            elif step["type"] == "input":
                # Return input data
                step_result["output"] = input_data
            
            elif step["type"] == "process":
                # Simulate processing
                step_result["output"] = {
                    "processed": True,
                    "result": "Data processed successfully"
                }
            
            elif step["type"] == "output":
                # Return output
                step_result["output"] = {
                    "format": "json",
                    "data": input_data
                }
            
            else:
                step_result["status"] = "warning"
                step_result["output"] = {"message": f"Unknown step type: {step['type']}"}
        
        except Exception as e:
            step_result["status"] = "error"
            step_result["output"] = {"error": str(e)}
        
        results.append(step_result)
    
    return {
        "steps_executed": len(results),
        "results": results,
        "overall_status": "success" if all(r["status"] == "success" for r in results) else "partial_success"
    }

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8004, debug=False)