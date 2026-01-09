from flask import Flask, request, jsonify
from gtts import gTTS
from moviepy.editor import *
import tempfile
import os
import base64
import io

app = Flask(__name__)

def text_to_speech(text, lang='en'):
    """Convert text to speech using gTTS"""
    tts = gTTS(text=text, lang=lang, slow=False)
    return tts

def create_video_from_images_and_audio(image_paths, audio_path, duration=5):
    """Create a video from images and audio"""
    # Create a list of ImageClips
    clips = []
    for image_path in image_paths:
        clip = ImageClip(image_path).set_duration(duration / len(image_paths))
        clips.append(clip)
    
    # Concatenate clips
    video = concatenate_videoclips(clips, method="compose")
    
    # Add audio
    audio = AudioFileClip(audio_path)
    final_audio = afx.audio_loop(audio, duration=video.duration)
    video = video.set_audio(final_audio)
    
    return video

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "video-generation"})

@app.route('/generate', methods=['POST'])
def generate_video():
    try:
        data = request.json
        text = data.get('text', '')
        image_prompts = data.get('image_prompts', [])
        
        if not text:
            return jsonify({"error": "Text is required"}), 400
        
        if not image_prompts:
            return jsonify({"error": "Image prompts are required"}), 400
        
        # Create temporary directory
        temp_dir = tempfile.mkdtemp()
        
        try:
            # Generate voiceover
            tts = text_to_speech(text)
            voiceover_path = os.path.join(temp_dir, "voiceover.mp3")
            tts.save(voiceover_path)
            
            # Generate images (for demo, create placeholder images)
            image_paths = []
            for i, prompt in enumerate(image_prompts):
                # In a real implementation, you would call the image generation service
                # For now, create a simple colored image
                img = Image.new('RGB', (640, 480), color=(i*50 % 255, (i*100) % 255, (i*150) % 255))
                img_path = os.path.join(temp_dir, f"image_{i}.png")
                img.save(img_path)
                image_paths.append(img_path)
            
            # Create video
            video = create_video_from_images_and_audio(image_paths, voiceover_path)
            
            # Save video to temporary file
            video_path = os.path.join(temp_dir, "output.mp4")
            video.write_videofile(video_path, codec='libx264', audio_codec='aac')
            
            # Read video file and convert to base64
            with open(video_path, 'rb') as f:
                video_bytes = f.read()
                video_base64 = base64.b64encode(video_bytes).decode()
            
            return jsonify({
                "text": text,
                "image_prompts": image_prompts,
                "video_base64": video_base64,
                "status": "success"
            })
            
        finally:
            # Clean up temporary files
            import shutil
            shutil.rmtree(temp_dir)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/text-to-speech', methods=['POST'])
def text_to_speech_only():
    try:
        data = request.json
        text = data.get('text', '')
        lang = data.get('lang', 'en')
        
        if not text:
            return jsonify({"error": "Text is required"}), 400
        
        # Generate voiceover
        tts = text_to_speech(text, lang)
        
        # Save to temporary file
        temp_dir = tempfile.mkdtemp()
        try:
            audio_path = os.path.join(temp_dir, "output.mp3")
            tts.save(audio_path)
            
            # Read audio file and convert to base64
            with open(audio_path, 'rb') as f:
                audio_bytes = f.read()
                audio_base64 = base64.b64encode(audio_bytes).decode()
            
            return jsonify({
                "text": text,
                "language": lang,
                "audio_base64": audio_base64,
                "status": "success"
            })
            
        finally:
            import shutil
            shutil.rmtree(temp_dir)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8002, debug=False)