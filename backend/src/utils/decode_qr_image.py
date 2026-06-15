import base64
import json
import re
import sys

import cv2
import numpy as np


def emit(payload):
    sys.stdout.write(json.dumps(payload))
    sys.stdout.flush()


def parse_image_data(image_data: str) -> bytes:
    if not image_data:
        raise ValueError("Missing image data")
    match = re.match(r"^data:image/[^;]+;base64,(.+)$", image_data, re.DOTALL)
    raw_b64 = match.group(1) if match else image_data
    return base64.b64decode(raw_b64)


def decode_qr(raw_bytes: bytes):
    image_buffer = np.frombuffer(raw_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_buffer, cv2.IMREAD_COLOR)
    if image is None:
        return None

    detector = cv2.QRCodeDetector()
    value, _points, _straight = detector.detectAndDecode(image)
    if value and value.strip():
        return value.strip()

    multi_ok, decoded_info, _points, _straight = detector.detectAndDecodeMulti(image)
    if multi_ok and decoded_info:
        for item in decoded_info:
            if item and item.strip():
                return item.strip()

    return None


def main():
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        raw_bytes = parse_image_data(payload.get("imageData", ""))
        decoded = decode_qr(raw_bytes)
        if not decoded:
            emit({"ok": False, "error": "No QR found in image"})
            return
        emit({"ok": True, "payload": decoded})
    except Exception as error:
        emit({"ok": False, "error": str(error)})


if __name__ == "__main__":
    main()
