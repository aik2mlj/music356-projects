import argparse
import time

import cv2
import mediapipe as mp
from pythonosc.udp_client import SimpleUDPClient


def clamp01(x: float) -> float:
    if x < 0.0:
        return 0.0
    if x > 1.0:
        return 1.0
    return x


def send_hand_landmarks(
    client,
    prefix,
    hand_landmarks,
    image_size,
):
    """
    Sends OSC messages for one hand.
    Coordinates:
      - normalized x,y in [0,1] (as MediaPipe gives)
      - pixel x,y for convenience
      - z is MediaPipe's relative depth (not meters)

    OSC addresses:
      /hands/<left|right>/present        int (1)
      /hands/<left|right>/lm/<i>         float x y z
      /hands/<left|right>/lm_px/<i>      int x_px y_px
      /hands/<left|right>/flat           float[63] (x,y,z repeated)
    """
    w, h = image_size
    client.send_message(f"/hands/{prefix}/present", 1)

    flat = []
    for i, lm in enumerate(hand_landmarks.landmark):
        x = clamp01(float(lm.x))
        y = clamp01(float(lm.y))
        z = float(lm.z)

        x_px = int(round(x * (w - 1)))
        y_px = int(round(y * (h - 1)))

        client.send_message(f"/hands/{prefix}/lm/{i}", [x, y, z])
        client.send_message(f"/hands/{prefix}/lm_px/{i}", [x_px, y_px])

        flat.extend([x, y, z])

    client.send_message(f"/hands/{prefix}/flat", flat)


def main() -> None:
    parser = argparse.ArgumentParser(description="MediaPipe Hands -> OSC (uv-friendly)")
    parser.add_argument("--camera", type=int, default=0, help="OpenCV camera index")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="OSC host")
    parser.add_argument("--port", type=int, default=8000, help="OSC UDP port")
    parser.add_argument("--fps", type=float, default=30.0, help="Target FPS (soft cap)")
    parser.add_argument("--max-hands", type=int, default=2, help="Max hands")
    parser.add_argument(
        "--no-preview",
        action="store_true",
        help="Disable preview window (still streams OSC).",
    )
    parser.add_argument(
        "--mirror",
        action="store_true",
        help="Mirror preview horizontally (like selfie view). Does not change OSC coords.",
    )

    args = parser.parse_args()

    client = SimpleUDPClient(args.host, args.port)
    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        raise RuntimeError(
            f"Could not open camera index {args.camera}. "
            "Try --camera 1 or check permissions / v4l2-ctl."
        )

    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=args.max_hands,
        model_complexity=1,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    mp_draw = mp.solutions.drawing_utils

    target_dt = 1.0 / max(args.fps, 1.0)
    last_time = time.time()

    try:
        while True:
            ok, frame = cap.read()
            if not ok or frame is None:
                continue

            h, w = frame.shape[:2]
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result = hands.process(rgb)

            # Default: mark hands absent
            client.send_message("/hands/left/present", 0)
            client.send_message("/hands/right/present", 0)

            if result.multi_hand_landmarks and result.multi_handedness:
                for hand_lms, handedness in zip(
                    result.multi_hand_landmarks, result.multi_handedness
                ):
                    label = handedness.classification[0].label  # "Left" or "Right"
                    prefix = "left" if label.lower() == "left" else "right"
                    send_hand_landmarks(client, prefix, hand_lms, (w, h))

                    if not args.no_preview:
                        mp_draw.draw_landmarks(frame, hand_lms, mp_hands.HAND_CONNECTIONS)

            if not args.no_preview:
                disp = frame
                if args.mirror:
                    disp = cv2.flip(disp, 1)
                cv2.imshow("MediaPipe Hands -> OSC", disp)
                if cv2.waitKey(1) & 0xFF == 27:  # ESC
                    break

            # soft FPS cap
            now = time.time()
            dt = now - last_time
            if dt < target_dt:
                time.sleep(target_dt - dt)
            last_time = time.time()

    finally:
        hands.close()
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
