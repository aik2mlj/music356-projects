#!/usr/bin/env python3
"""
camera_input.py

Python translation of the Processing sketch cameraInput.pde:
- captures webcam frames
- displays them
- downsamples (by commonFactor in both width/height)
- further samples pixels by sampleInterval
- sends RGB triplets as OSC floats to Wekinator at /wek/inputs (default localhost:6448)

Deps:
  pip install opencv-python python-osc numpy

Run:
  python camera_input.py
  python camera_input.py --common-factor 80 --sample-interval 8 --camera-index 0
"""

import argparse
import sys
import time

import cv2
import numpy as np
from pythonosc.udp_client import SimpleUDPClient


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="127.0.0.1", help="OSC destination host (default: 127.0.0.1)")
    p.add_argument("--port", type=int, default=6448, help="OSC destination port (default: 6448)")
    p.add_argument("--address", default="/wek/inputs", help="OSC address (default: /wek/inputs)")
    p.add_argument("--camera-index", type=int, default=0, help="OpenCV camera index (default: 0)")
    p.add_argument("--width", type=int, default=1280, help="Capture width (default: 1280)")
    p.add_argument("--height", type=int, default=720, help="Capture height (default: 720)")
    p.add_argument(
        "--common-factor",
        type=int,
        default=80,
        help="Downsample factor for width/height (default: 80)",
    )
    p.add_argument(
        "--sample-interval", type=int, default=8, help="Stride over downsampled pixels (default: 8)"
    )
    p.add_argument("--fps-limit", type=float, default=0.0, help="Optional FPS cap (0 = uncapped)")
    return p.parse_args()


def main():
    args = parse_args()

    if args.common_factor <= 0:
        print("commonFactor must be > 0", file=sys.stderr)
        return 2
    if args.sample_interval <= 0:
        print("sampleInterval must be > 0", file=sys.stderr)
        return 2

    client = SimpleUDPClient(args.host, args.port)

    cap = cv2.VideoCapture(args.camera_index)
    if not cap.isOpened():
        print(f"Could not open camera index {args.camera_index}", file=sys.stderr)
        return 1

    # Try to match Processing sketch resolution.
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, float(args.width))
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, float(args.height))

    target_w = max(1, args.width // args.common_factor)
    target_h = max(1, args.height // args.common_factor)

    last_time = time.time()

    while True:
        ok, frame_bgr = cap.read()
        if not ok:
            print("Camera read failed.", file=sys.stderr)
            break

        # Display (Processing: image(cam, 0, 0))
        cv2.imshow("camera_input (press q to quit)", frame_bgr)

        # Processing used PImage.get() of the canvas, then resize.
        # Here we resize the captured frame directly.
        small_bgr = cv2.resize(frame_bgr, (target_w, target_h), interpolation=cv2.INTER_AREA)

        # OpenCV frame is BGR; convert to RGB to match Processing's red/green/blue.
        small_rgb = cv2.cvtColor(small_bgr, cv2.COLOR_BGR2RGB)

        # Flatten pixels in row-major order: shape (H*W, 3)
        pixels = small_rgb.reshape(-1, 3)

        # Take every sampleInterval-th pixel (naive sampling, like the sketch)
        sampled = pixels[:: args.sample_interval]

        # Build OSC args: R, G, B for each sampled pixel, sent as floats
        # (Processing's red()/green()/blue() return floats in [0,255])
        osc_args = sampled.astype(np.float32).reshape(-1).tolist()

        # Send message
        client.send_message(args.address, osc_args)

        # Quit control
        key = cv2.waitKey(1) & 0xFF
        if key == ord("q"):
            break

        # Optional FPS cap
        if args.fps_limit and args.fps_limit > 0:
            now = time.time()
            dt = now - last_time
            min_dt = 1.0 / args.fps_limit
            if dt < min_dt:
                time.sleep(min_dt - dt)
            last_time = time.time()

    cap.release()
    cv2.destroyAllWindows()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
