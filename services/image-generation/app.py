from flask import Flask, request, jsonify
import torch
from PIL import Image
import numpy as np
import io
import base64

app = Flask(__name__)

# Initialize image generation model
try:
    # Using a simple diffusion model for demonstration
    from diffusers import StableDiffusionPipeline
    
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = StableDiffusionPipeline.from_pretrained("CompVis/stable-diffusion-v1-4", torch_dtype=torch.float16)
    model = model.to(device)
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

def encode_image_to_base64(image):
    """Convert PIL Image to base64 string"""
    buffered = io.BytesIO()
    image.save(buffered, format="PNG")
    img_str = base64.b64encode(buffered.getvalue()).decode()
    return img_str

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "image-generation"})

@app.route('/generate', methods=['POST'])
def generate_image():
    if not model:
        return jsonify({"error": "Model not available"}), 500
    
    try:
        data = request.json
        prompt = data.get('prompt', '')
        
        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400
        
        # Generate image
        with torch.autocast("cuda"):
            image = model(prompt).images[0]
        
        # Convert to base64
        image_base64 = encode_image_to_base64(image)
        
        return jsonify({
            "prompt": prompt,
            "image_base64": image_base64,
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/batch-generate', methods=['POST'])
def batch_generate():
    if not model:
        return jsonify({"error": "Model not available"}), 500
    
    try:
        data = request.json
        prompts = data.get('prompts', [])
        
        if not prompts:
            return jsonify({"error": "Prompts array is required"}), 400
        
        results = []
        for prompt in prompts:
            with torch.autocast("cuda"):
                image = model(prompt).images[0]
            image_base64 = encode_image_to_base64(image)
            results.append({
                "prompt": prompt,
                "image_base64": image_base64
            })
        
        return jsonify({
            "results": results,
            "count": len(results),
            "status": "success"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001, debug=False)