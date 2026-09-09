import os
import sys

# Add backend to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from app.ml.inference import predict_image_bytes
    from PIL import Image
    import io
    
    # Create 1x1 image
    img = Image.new('RGB', (100, 100), color = 'red')
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    img_bytes = img_byte_arr.getvalue()
    
    print("Running inference...")
    res = predict_image_bytes(img_bytes)
    print("Result:", res)
    
except Exception as e:
    print("Error:", e)
