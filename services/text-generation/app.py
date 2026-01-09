from flask import Flask, request, jsonify
from transformers import pipeline

app = Flask(__name__)

# Initialize text generation model
try:
    generator = pipeline('text-generation', model='gpt2', max_length=500)
except Exception as e:
    print(f"Error loading model: {e}")
    generator = None

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "text-generation"})

@app.route('/generate', methods=['POST'])
def generate_text():
    if not generator:
        return jsonify({"error": "Model not available"}), 500
    
    try:
        data = request.json
        prompt = data.get('prompt', '')
        language = data.get('language', 'en')
        
        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400
        
        # Generate text
        response = generator(prompt, max_length=500, num_return_sequences=1)
        generated_text = response[0]['generated_text']
        
        return jsonify({
            "prompt": prompt,
            "language": language,
            "generated_text": generated_text,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/batch-generate', methods=['POST'])
def batch_generate():
    if not generator:
        return jsonify({"error": "Model not available"}), 500
    
    try:
        data = request.json
        prompts = data.get('prompts', [])
        
        if not prompts:
            return jsonify({"error": "Prompts array is required"}), 400
        
        results = []
        for prompt in prompts:
            response = generator(prompt, max_length=500, num_return_sequences=1)
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)