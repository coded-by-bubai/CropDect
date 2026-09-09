import os
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
from app.core.logging import logger

PLANTVILLAGE_CLASSES = [
    'Apple___Apple_scab', 'Apple___Black_rot', 'Apple___Cedar_apple_rust', 'Apple___healthy',
    'Blueberry___healthy', 'Cherry_(including_sour)___Powdery_mildew', 'Cherry_(including_sour)___healthy',
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot', 'Corn_(maize)___Common_rust_',
    'Corn_(maize)___Northern_Leaf_Blight', 'Corn_(maize)___healthy', 'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)', 'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)', 'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)', 'Peach___Bacterial_spot', 'Peach___healthy',
    'Pepper,_bell___Bacterial_spot', 'Pepper,_bell___healthy', 'Potato___Early_blight',
    'Potato___Late_blight', 'Potato___healthy', 'Raspberry___healthy', 'Soybean___healthy',
    'Squash___Powdery_mildew', 'Strawberry___Leaf_scorch', 'Strawberry___healthy',
    'Tomato___Bacterial_spot', 'Tomato___Early_blight', 'Tomato___Late_blight', 'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot', 'Tomato___Spider_mites Two-spotted_spider_mite', 'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus', 'Tomato___Tomato_mosaic_virus', 'Tomato___healthy'
]

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = None

def load_model():
    global model
    if model is not None:
        return
        
    model_path = os.path.join(os.path.dirname(__file__), '..', '..', 'ml', 'model.pt')
    
    try:
        # Recreate architecture
        model = models.mobilenet_v2(weights=None)
        model.classifier[1] = nn.Linear(model.last_channel, len(PLANTVILLAGE_CLASSES))
        
        if os.path.exists(model_path):
            model.load_state_dict(torch.load(model_path, map_location=device))
            logger.info("Real ML Model loaded successfully.")
        else:
            logger.warning(f"Model file not found at {model_path}. Using untrained weights.")
            
        model = model.to(device)
        model.eval()
    except Exception as e:
        logger.error(f"Error loading ML model: {e}")
        model = None

def _predict_pil_image(image: Image.Image):
    load_model()
    
    if model is None:
        return {
            "class_name": "Unknown___Error",
            "confidence": 0.0,
            "is_healthy": False
        }
    
    transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    try:
        image_tensor = transform(image).unsqueeze(0).to(device)
        
        with torch.no_grad():
            outputs = model(image_tensor)
            probabilities = torch.nn.functional.softmax(outputs, dim=1)
            confidence, predicted_idx = torch.max(probabilities, 1)
            
        class_idx = predicted_idx.item()
        class_name = PLANTVILLAGE_CLASSES[class_idx]
        
        # Simple heuristic for healthy vs diseased
        is_healthy = "healthy" in class_name.lower()
        
        return {
            "class_name": class_name,
            "confidence": confidence.item(),
            "is_healthy": is_healthy,
            "class_index": class_idx
        }
    except Exception as e:
        logger.error(f"Inference error: {e}")
        return {
            "class_name": "Unknown___Error",
            "confidence": 0.0,
            "is_healthy": False
        }

import io
def predict_image(image_input) -> dict:
    if isinstance(image_input, (bytes, bytearray)):
        image = Image.open(io.BytesIO(image_input)).convert('RGB')
    elif isinstance(image_input, Image.Image):
        image = image_input
    else:
        image = Image.open(image_input).convert('RGB')
    return _predict_pil_image(image)

def predict_image_bytes(image_bytes: bytes) -> dict:
    import app.ml.inference
    return app.ml.inference.predict_image(image_bytes)
