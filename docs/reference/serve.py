# Local stand-in for the Render-hosted AI Processing Layer (Section 3.10).
# Runs on your own machine; prototype/index.html calls http://localhost:5001
# during local (file://) testing. This is NOT deployed anywhere public yet --
# see README.md for why that's fine for now and what changes once it is.
#
# Run with:  venv\Scripts\python.exe serve.py
import json
import sys
from pathlib import Path

import joblib
from flask import Flask, Response, jsonify, request
from flask_cors import CORS

from extract import extract_text_from_upload
from classify import classify, MODEL_PATH, LABELS
from rectify import rectify

sys.stdout.reconfigure(encoding="utf-8")

app = Flask(__name__)
CORS(app)  # local dev tool only -- wide open on purpose, tighten before any real deployment

_bundle = None


def get_model():
    global _bundle
    if _bundle is None:
        if not MODEL_PATH.exists():
            raise RuntimeError("No trained model found -- run `python classify.py` once first.")
        _bundle = joblib.load(MODEL_PATH)
    return _bundle


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"ok": True, "labels": LABELS})


# Debug/visual-check endpoint for Document Image Rectification (Section
# 1.3/1.9) on its own, separate from /classify -- lets you actually SEE the
# deskew/crop/contrast-normalize result on a photo before trusting it inside
# the full OCR+classify pipeline. Not called by prototype/index.html.
@app.route("/rectify", methods=["POST"])
def rectify_route():
    if "file" not in request.files:
        return jsonify({"error": "attach a multipart 'file'"}), 400
    f = request.files["file"]
    data = f.read()
    if not data:
        return jsonify({"error": "empty file"}), 400
    processed, info = rectify(data)
    resp = Response(processed, mimetype="image/jpeg")
    resp.headers["X-Rectify-Info"] = json.dumps(info)
    return resp


@app.route("/classify", methods=["POST"])
def classify_route():
    bundle = get_model()
    vectorizer, prototypes = bundle["vectorizer"], bundle["prototypes"]

    if "file" in request.files:
        f = request.files["file"]
        data = f.read()
        if not data:
            return jsonify({"error": "empty file"}), 400
        try:
            text = extract_text_from_upload(data, f.filename or "upload.pdf")
        except Exception as e:
            return jsonify({"error": f"could not read file: {e}"}), 400
    else:
        body = request.get_json(silent=True) or {}
        text = (body.get("text") or "").strip()

    if not text:
        return jsonify({"error": "no readable text found"}), 400

    label, confidence, sims = classify(text, vectorizer, prototypes)
    return jsonify({
        "type": label,
        "confidence": confidence,
        "similarities": {k: round(v, 3) for k, v in sims.items()},
        "textPreview": text[:200],
    })


if __name__ == "__main__":
    get_model()  # fail fast at startup if the model isn't trained yet
    print("DocuRoute local classify API running at http://localhost:5001")
    print("Endpoints: GET /health, POST /classify (multipart 'file' or JSON {text})")
    app.run(host="127.0.0.1", port=5001, debug=False)
