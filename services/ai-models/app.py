from flask import Flask, request, jsonify
from transformers import pipeline
import torch
import numpy as np
from sklearn.ensemble import IsolationForest
import joblib

app = Flask(__name__)

# Initialize models
try:
    # Large Language Model
    llm = pipeline('text-generation', model='gpt2', max_length=500)
    
    # Specialized models
    # For demonstration, we'll use simple models
    # In production, these would be loaded from model files
    specialized_models = {
        'adult_content_detector': None,  # Placeholder
        'phishing_detector': None,       # Placeholder
        'vulnerability_analyzer': None   # Placeholder
    }
    
except Exception as e:
    print(f"Error loading models: {e}")
    llm = None

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "ai-models"})

@app.route('/llm/generate', methods=['POST'])
def use_llm():
    if not llm:
        return jsonify({"error": "LLM not available"}), 500
    
    try:
        data = request.json
        prompt = data.get('prompt', '')
        model_name = data.get('model_name', 'gpt2')
        
        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400
        
        # Generate text
        response = llm(prompt, max_length=500, num_return_sequences=1)
        generated_text = response[0]['generated_text']
        
        return jsonify({
            "prompt": prompt,
            "model_name": model_name,
            "generated_text": generated_text,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/llm/batch-generate', methods=['POST'])
def batch_llm_generate():
    if not llm:
        return jsonify({"error": "LLM not available"}), 500
    
    try:
        data = request.json
        prompts = data.get('prompts', [])
        
        if not prompts:
            return jsonify({"error": "Prompts array is required"}), 400
        
        results = []
        for prompt in prompts:
            response = llm(prompt, max_length=500, num_return_sequences=1)
            results.append({
                "prompt": prompt,
                "generated_text": response[0]['generated_text']
            })
        
        return jsonify({
            "results": results,
            "count": len(results),
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/specialized/predict', methods=['POST'])
def specialized_predict():
    """Generic endpoint for specialized model predictions"""
    try:
        data = request.json
        model_type = data.get('model_type', '')
        input_data = data.get('input_data', {})
        
        if not model_type:
            return jsonify({"error": "Model type is required"}), 400
        
        if model_type == 'anomaly_detection':
            # Simple anomaly detection using Isolation Forest
            features = input_data.get('features', [])
            if not features:
                return jsonify({"error": "Features array is required"}), 400
            
            # Reshape for sklearn
            X = np.array(features).reshape(-1, 1)
            
            # Train or load model
            model = IsolationForest(contamination=0.1)
            model.fit(X)
            
            # Predict
            predictions = model.predict(X)
            anomaly_scores = model.decision_function(X)
            
            return jsonify({
                "model_type": model_type,
                "predictions": predictions.tolist(),
                "anomaly_scores": anomaly_scores.tolist(),
                "status": "success"
            })
        
        elif model_type == 'text_classification':
            # Simple text classification using LLM
            if not llm:
                return jsonify({"error": "LLM not available"}), 500
            
            text = input_data.get('text', '')
            if not text:
                return jsonify({"error": "Text is required"}), 400
            
            # Generate classification prompt
            classification_prompt = f"Classify the following text as positive, negative, or neutral: '{text}'"
            response = llm(classification_prompt, max_length=100, num_return_sequences=1)
            
            return jsonify({
                "model_type": model_type,
                "text": text,
                "classification": response[0]['generated_text'],
                "status": "success"
            })
        
        else:
            return jsonify({"error": f"Unknown model type: {model_type}"}), 400
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/model/train', methods=['POST'])
def train_model():
    """Endpoint for training custom models"""
    try:
        data = request.json
        model_type = data.get('model_type', '')
        training_data = data.get('training_data', {})
        
        if not model_type or not training_data:
            return jsonify({"error": "Model type and training data are required"}), 400
        
        if model_type == 'anomaly_detection':
            # Train anomaly detection model
            features = training_data.get('features', [])
            if not features:
                return jsonify({"error": "Features array is required"}), 400
            
            X = np.array(features).reshape(-1, 1)
            model = IsolationForest(contamination=0.1)
            model.fit(X)
            
            # Save model
            model_path = f"/app/models/anomaly_detection_model.pkl"
            os.makedirs(os.path.dirname(model_path), exist_ok=True)
            joblib.dump(model, model_path)
            
            return jsonify({
                "model_type": model_type,
                "model_path": model_path,
                "status": "success",
                "message": "Model trained and saved successfully"
            })
        
        else:
            return jsonify({"error": f"Training not implemented for model type: {model_type}"}), 501
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8003, debug=False)