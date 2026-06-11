"""
CareConnect – Python Flask Backend
Alzheimer's MRI Classification API using Transfer Learning (EfficientNetB3)
"""

import os
import io
import uuid
import logging
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS

# ── TensorFlow / Keras ────────────────────────────────────────────────────────
import tensorflow as tf
from tensorflow.keras.applications import EfficientNetB3
from tensorflow.keras.applications.efficientnet import preprocess_input
from tensorflow.keras.models import Model, load_model
from tensorflow.keras.layers import (
    GlobalAveragePooling2D, Dense, Dropout, BatchNormalization
)
from tensorflow.keras.optimizers import Adam

# ── Image processing ──────────────────────────────────────────────────────────
from PIL import Image
import cv2

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ── Constants ─────────────────────────────────────────────────────────────────
IMG_SIZE       = 224          # EfficientNetB3 minimum; we keep 224 for speed
NUM_CLASSES    = 4
CLASS_LABELS   = [
    "Mild Demented",
    "Moderate Demented",
    "Non Demented",
    "Very Mild Demented",
]
MODEL_PATH     = os.path.join(os.path.dirname(__file__), "alzheimers_efficientnet.h5")
MAX_FILE_BYTES = 10 * 1024 * 1024   # 10 MB guard


# ── Model builder ─────────────────────────────────────────────────────────────
def build_model() -> Model:
    """
    EfficientNetB3 backbone with a custom classification head.
    Fine-tunes the top 30 layers of the backbone so the feature extractor
    adapts to grayscale-like MRI textures.
    """
    base = EfficientNetB3(
        weights="imagenet",
        include_top=False,
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
    )

    # Freeze all backbone layers initially
    base.trainable = True
    for layer in base.layers[:-30]:
        layer.trainable = False

    x = base.output
    x = GlobalAveragePooling2D()(x)
    x = BatchNormalization()(x)
    x = Dense(512, activation="relu")(x)
    x = Dropout(0.4)(x)
    x = Dense(256, activation="relu")(x)
    x = Dropout(0.3)(x)
    outputs = Dense(NUM_CLASSES, activation="softmax")(x)

    model = Model(inputs=base.input, outputs=outputs)
    model.compile(
        optimizer=Adam(learning_rate=1e-4),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    logger.info("Model built: %d trainable params", model.count_params())
    return model


# ── Lazy-load the model once ──────────────────────────────────────────────────
_model: Model | None = None


def get_model() -> Model:
    global _model
    if _model is None:
        if os.path.exists(MODEL_PATH):
            logger.info("Loading saved model from %s", MODEL_PATH)
            _model = load_model(MODEL_PATH)
        else:
            logger.warning(
                "No saved model found at %s – building fresh model with ImageNet weights. "
                "Predictions will be RANDOM until the model is trained on MRI data.",
                MODEL_PATH,
            )
            _model = build_model()
    return _model


# ── Image pre-processing ──────────────────────────────────────────────────────
def preprocess_image(file_bytes: bytes) -> np.ndarray:
    """
    1. Decode bytes → PIL Image
    2. Convert to RGB (handles grayscale DICOM exports saved as PNG/JPG)
    3. CLAHE contrast enhancement (improves MRI lesion visibility)
    4. Resize to IMG_SIZE × IMG_SIZE
    5. EfficientNet-specific normalisation
    """
    # Decode
    pil_img = Image.open(io.BytesIO(file_bytes)).convert("RGB")
    img_np  = np.array(pil_img)

    # CLAHE on L channel of LAB colour space
    lab   = cv2.cvtColor(img_np, cv2.COLOR_RGB2LAB)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    img_np = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)

    # Resize
    img_resized = cv2.resize(img_np, (IMG_SIZE, IMG_SIZE))

    # EfficientNet pre-processing (scales to [-1, 1])
    img_array = preprocess_input(img_resized.astype(np.float32))

    return np.expand_dims(img_array, axis=0)   # shape: (1, H, W, 3)


# ── Routes ────────────────────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "model_loaded": _model is not None})


@app.route("/predict", methods=["POST"])
def predict():
    """
    Expects multipart/form-data with field `image` (JPEG/PNG).
    Returns:
      {
        "prediction":  "Non Demented",
        "confidence":  94.3,
        "all_classes": {
          "Mild Demented": 1.2,
          "Moderate Demented": 0.5,
          "Non Demented": 94.3,
          "Very Mild Demented": 4.0
        }
      }
    """
    if "image" not in request.files:
        return jsonify({"error": "No image file provided. Use field name 'image'."}), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({"error": "Empty filename."}), 400

    file_bytes = file.read()
    if len(file_bytes) > MAX_FILE_BYTES:
        return jsonify({"error": "File too large (max 10 MB)."}), 413

    try:
        img_input = preprocess_image(file_bytes)
    except Exception as exc:
        logger.exception("Image preprocessing failed")
        return jsonify({"error": f"Image preprocessing failed: {str(exc)}"}), 422

    try:
        model       = get_model()
        predictions = model.predict(img_input, verbose=0)[0]   # shape: (4,)
    except Exception as exc:
        logger.exception("Model inference failed")
        return jsonify({"error": f"Model inference failed: {str(exc)}"}), 500

    # Build response
    probs       = {label: round(float(prob) * 100, 2)
                   for label, prob in zip(CLASS_LABELS, predictions)}
    top_idx     = int(np.argmax(predictions))
    top_label   = CLASS_LABELS[top_idx]
    top_conf    = probs[top_label]

    logger.info("Prediction: %s (%.1f%%)", top_label, top_conf)

    return jsonify({
        "prediction":  top_label,
        "confidence":  top_conf,
        "all_classes": probs,
    })


@app.route("/model/info", methods=["GET"])
def model_info():
    model = get_model()
    return jsonify({
        "architecture": "EfficientNetB3 + Custom Head",
        "input_shape":  list(model.input_shape[1:]),
        "num_classes":  NUM_CLASSES,
        "class_labels": CLASS_LABELS,
        "model_file_exists": os.path.exists(MODEL_PATH),
    })


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Pre-warm the model before the first request
    get_model()
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
