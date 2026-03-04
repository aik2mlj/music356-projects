import argparse
import time
from typing import Dict, List, Tuple

import cv2
import mediapipe as mp
import numpy as np
from pythonosc.udp_client import SimpleUDPClient


def clamp01(x: float) -> float:
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def send_present(client: SimpleUDPClient, path: str, present: int) -> None:
    client.send_message(f"{path}/present", int(present))


def dist2d(a, b) -> float:
    dx = float(a.x) - float(b.x)
    dy = float(a.y) - float(b.y)
    return (dx * dx + dy * dy) ** 0.5


def send_smile_features(client: SimpleUDPClient, face_lms) -> None:
    """
    Sends a small feature vector for Wekinator.
    OSC:
      /smile/present 0/1
      /smile/features [smile_score, mouth_width, mouth_open]
    """
    if face_lms is None:
        client.send_message("/smile/present", 0)
        return

    lm = face_lms.landmark
    # FaceMesh indices:
    # mouth corners: 61, 291
    # lip centers: 13 (upper), 14 (lower)
    left = lm[61]
    right = lm[291]
    upper = lm[13]
    lower = lm[14]

    mouth_width = dist2d(left, right)
    mouth_open = dist2d(upper, lower)

    eps = 1e-6
    smile_score = mouth_width / (mouth_open + eps)

    client.send_message("/smile/present", 1)
    client.send_message("/smile/features", [smile_score, mouth_width, mouth_open])


FACE_SMALL = [1, 33, 61, 199, 263, 291]  # nose, eyes, mouth corners, chin-ish


def draw_sparse_face(frame, face_lms):
    if face_lms is None:
        return

    h, w = frame.shape[:2]
    for idx in FACE_SMALL:
        lm = face_lms.landmark[idx]
        x = int(lm.x * w)
        y = int(lm.y * h)
        cv2.circle(frame, (x, y), 4, (0, 255, 0), -1)


def send_landmarks_normalized(
    client: SimpleUDPClient,
    base: str,
    landmarks,
    image_size: Tuple[int, int],
    send_per_point: bool = True,
    send_flat: bool = True,
    send_px: bool = True,
) -> None:
    """
    Send a landmark list that has normalized x,y and relative z (MediaPipe normalized landmarks).
    OSC:
      <base>/present                 0/1
      <base>/lm/<i>                  float x y z
      <base>/lm_px/<i>               int x_px y_px
      <base>/flat                    float[3N]
    """
    w, h = image_size
    if landmarks is None:
        send_present(client, base, 0)
        return

    send_present(client, base, 1)

    flat: List[float] = []
    for i, lm in enumerate(landmarks.landmark):
        x = clamp01(float(lm.x))
        y = clamp01(float(lm.y))
        z = float(lm.z)

        if send_per_point:
            client.send_message(f"{base}/lm/{i}", [x, y, z])

        if send_px:
            x_px = int(round(x * (w - 1)))
            y_px = int(round(y * (h - 1)))
            client.send_message(f"{base}/lm_px/{i}", [x_px, y_px])

        if send_flat:
            flat.extend([x, y, z])

    if send_flat:
        client.send_message(f"{base}/flat", flat)


def send_pose_world_landmarks(
    client: SimpleUDPClient,
    base: str,
    world_landmarks,
    send_per_point: bool = True,
    send_flat: bool = True,
) -> None:
    """
    Send pose_world_landmarks (x,y,z in meters-ish world coordinates relative to mid-hips).
    OSC:
      <base>/present                 0/1
      <base>/pt/<i>                  float x y z
      <base>/flat                    float[3N]
    """
    if world_landmarks is None:
        send_present(client, base, 0)
        return

    send_present(client, base, 1)

    flat: List[float] = []
    for i, lm in enumerate(world_landmarks.landmark):
        x = float(lm.x)
        y = float(lm.y)
        z = float(lm.z)

        if send_per_point:
            client.send_message(f"{base}/pt/{i}", [x, y, z])

        if send_flat:
            flat.extend([x, y, z])

    if send_flat:
        client.send_message(f"{base}/flat", flat)


def main() -> None:
    parser = argparse.ArgumentParser(description="MediaPipe Holistic -> OSC (pose+face+hands)")
    parser.add_argument("--camera", type=int, default=0, help="OpenCV camera index")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="OSC host")
    parser.add_argument("--port", type=int, default=6448, help="OSC UDP port")

    parser.add_argument("--fps", type=float, default=30.0, help="Target FPS (soft cap)")
    parser.add_argument("--no-preview", action="store_true", help="Disable preview window.")
    parser.add_argument("--mirror-preview", action="store_true", help="Mirror the preview window.")

    parser.add_argument(
        "--mirror-osc",
        action="store_true",
        help="Mirror OSC x coordinates (x := 1-x) for normalized landmarks (pose/face/hands).",
    )

    parser.add_argument(
        "--model-complexity",
        type=int,
        default=1,
        choices=[0, 1, 2],
        help="Holistic model complexity (0=light, 2=heavy).",
    )

    parser.add_argument("--min-det", type=float, default=0.5, help="Min detection confidence")
    parser.add_argument("--min-track", type=float, default=0.5, help="Min tracking confidence")

    args = parser.parse_args()

    client = SimpleUDPClient(args.host, args.port)

    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        raise RuntimeError(
            f"Could not open camera index {args.camera}. Try --camera 1, or check v4l2-ctl."
        )

    mp_holistic = mp.solutions.holistic
    mp_draw = mp.solutions.drawing_utils

    holistic = mp_holistic.Holistic(
        static_image_mode=False,
        model_complexity=args.model_complexity,
        smooth_landmarks=True,
        enable_segmentation=False,
        refine_face_landmarks=True,
        min_detection_confidence=args.min_det,
        min_tracking_confidence=args.min_track,
    )

    def maybe_mirror_normalized_landmarks(landmarks):
        if not args.mirror_osc or landmarks is None:
            return landmarks
        # Create a shallow copy-like structure by modifying in place (acceptable for streaming)
        for lm in landmarks.landmark:
            lm.x = 1.0 - lm.x
        return landmarks

    target_dt = 1.0 / max(args.fps, 1.0)
    last = time.time()

    try:
        while True:
            ok, frame = cap.read()
            if not ok or frame is None:
                continue

            h, w = frame.shape[:2]

            # MediaPipe expects RGB
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            res = holistic.process(rgb)

            # Default: mark absent each frame; overwrite if present
            # Pose (normalized + world)
            # send_present(client, "/pose", 0)
            # send_present(client, "/pose_world", 0)
            # Face
            # send_present(client, "/face", 0)
            # Hands
            # send_present(client, "/hands/left", 0)
            # send_present(client, "/hands/right", 0)

            # Pose normalized landmarks
            pose_lms = res.pose_landmarks
            pose_lms = maybe_mirror_normalized_landmarks(pose_lms)
            send_landmarks_normalized(
                client, "/pose", pose_lms, (w, h), send_per_point=True, send_flat=True
            )

            # Pose world landmarks
            send_pose_world_landmarks(
                client, "/pose_world", res.pose_world_landmarks, send_per_point=True, send_flat=True
            )

            # Face landmarks (468)
            face_lms = res.face_landmarks
            face_lms = maybe_mirror_normalized_landmarks(face_lms)
            send_smile_features(client, face_lms)
            send_landmarks_normalized(
                client,
                "/face",
                face_lms,
                (w, h),
                send_per_point=False,
                send_flat=True,
                send_px=False,
            )

            # Hands
            left_hand = res.left_hand_landmarks
            right_hand = res.right_hand_landmarks

            left_hand = maybe_mirror_normalized_landmarks(left_hand)
            right_hand = maybe_mirror_normalized_landmarks(right_hand)

            send_landmarks_normalized(
                client, "/hands/left", left_hand, (w, h), send_per_point=True, send_flat=True
            )
            send_landmarks_normalized(
                client, "/hands/right", right_hand, (w, h), send_per_point=True, send_flat=True
            )

            # Preview (optional)
            if not args.no_preview:
                # if pose_lms is not None:
                # mp_draw.draw_landmarks(frame, pose_lms, mp_holistic.POSE_CONNECTIONS)
                if left_hand is not None:
                    mp_draw.draw_landmarks(frame, left_hand, mp_holistic.HAND_CONNECTIONS)
                if right_hand is not None:
                    mp_draw.draw_landmarks(frame, right_hand, mp_holistic.HAND_CONNECTIONS)
                if face_lms is not None:
                    # mp_draw.draw_landmarks(frame, face_lms, mp_holistic.FACEMESH_TESSELATION)
                    # draw_sparse_face(frame, face_lms)
                    pass

                disp = cv2.flip(frame, 1) if args.mirror_preview else frame
                cv2.imshow("MediaPipe Holistic -> OSC", disp)
                if cv2.waitKey(1) & 0xFF == 27:  # ESC
                    break

            # soft FPS cap
            now = time.time()
            dt = now - last
            if dt < target_dt:
                time.sleep(target_dt - dt)
            last = time.time()

    finally:
        holistic.close()
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
