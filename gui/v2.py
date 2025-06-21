#!/usr/bin/env python3
"""
NeoMind Ultra-Minimal – Enhanced GUI with Animated Eyes
------------------------------------------------------
• Keeps the same ultra-light dependency footprint (Tkinter + stdlib + optional audio)
• Adds a small "face" canvas that renders two eyes and updates them according to
  the current emotional state (happy, excited, thinking, listening, confused).
• Implements a lightweight blinking animation (randomised 3-6 s) that works
  even when the app is idle.
• Everything still works on plain X11 without additional fonts: colours + simple
  vector shapes only.

Author: ChatGPT (improved for Mohamed Khedher – 20 Jun 2025)
"""

import os
import sys
import warnings
import threading
import random
from datetime import datetime

# ═══════════ Runtime Noise Suppression ═══════════
warnings.filterwarnings("ignore")
os.environ["ALSA_SUPPRESS_ERRORS"] = "1"
os.environ["PYTHONWARNINGS"] = "ignore"

# ═══════════ Minimal Imports ═══════════
import tkinter as tk
from tkinter import messagebox
import requests

# Optional audio stack
has_audio = False
has_whisper = False
has_tts = False
try:
    import pyaudio
    import webrtcvad  # noqa: F401  (used only to verify availability)
    has_audio = True
except Exception:
    pass
try:
    import whisper  # noqa: F401
    has_whisper = True
except Exception:
    pass
try:
    import pyttsx3
    has_tts = True
except Exception:
    pass

print("🧠 NeoMind Ultra-Minimal – Starting…")


# ═══════════ Helper: Colour Palette ═══════════
CYAN = "#00FFCC"
WHITE = "#FFFFFF"
BLACK = "#000000"


class UltraMinimalNeoMind:
    """Ultra-minimal version, now with animated eyes"""

    def __init__(self):
        # ---------- State ----------
        self.child_name = "friend"
        self.server_url = "http://localhost:5000"
        self.current_emotion = "Happy :)"
        self.is_listening = False
        self._blink_job = None  # after() handle

        # ---------- Optional components ----------
        self.whisper_model = None
        self.tts_engine = None
        self.audio = None

        # ---------- Init ----------
        self.init_components()
        self.create_gui()

    # ═══════════  Sub-system Init  ═══════════
    def init_components(self):
        if has_whisper:
            try:
                print("Loading Whisper…")
                self.whisper_model = whisper.load_model("tiny.en")
                print("Whisper loaded ✔")
            except Exception as e:
                print(f"Whisper failed: {e}")
        if has_tts:
            try:
                self.tts_engine = pyttsx3.init()
                self.tts_engine.setProperty("rate", 150)
            except Exception as e:
                print(f"TTS failed: {e}")
        if has_audio:
            try:
                import contextlib
                with open(os.devnull, "w") as devnull:
                    with contextlib.redirect_stderr(devnull):
                        self.audio = pyaudio.PyAudio()
                print("Audio stack ready ✔")
            except Exception as e:
                print(f"Audio failed: {e}")

    # ═══════════  GUI  ═══════════
    def create_gui(self):
        self.root = tk.Tk()
        self.root.option_add("*Font", "TkDefaultFont")  # use default font only
        self.root.title("NeoMind Minimal")
        self.root.geometry("600x400")
        self.root.configure(bg="lightgray")

        # Center window
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - 300
        y = (self.root.winfo_screenheight() // 2) - 200
        self.root.geometry(f"600x400+{x}+{y}")

        # ---------- Main containers ----------
        main = tk.Frame(self.root, bg="lightgray")
        main.pack(fill="both", expand=True, padx=10, pady=10)

        tk.Label(main, text="NeoMind AI Companion", bg="lightgray", fg="darkblue").pack()

        # --- Emotion / face area ---
        self.emotion_frame = tk.Frame(main, bg="lightyellow", relief="ridge", bd=2)
        self.emotion_frame.pack(pady=5)

        # Canvas for eyes (200×100)
        self.face_canvas = tk.Canvas(
            self.emotion_frame, width=200, height=100, bg=BLACK, highlightthickness=0
        )
        self.face_canvas.pack()

        # Status line beneath canvas
        self.emotion_label = tk.Label(self.emotion_frame, text="Neo is Happy :)", bg="lightyellow")
        self.emotion_label.pack(fill="x")

        # --- Controls + chat area (rest of original UI) ---
        self._build_controls(main)
        self._build_chat(main)

        # Bindings
        self.root.bind("<Return>", lambda e: self.send_message())

        # Initial face + blink schedule
        self.draw_face(self.current_emotion)
        self.schedule_blink()

        print("🚀 GUI created successfully")

    def _build_controls(self, parent):
        controls = tk.Frame(parent, bg="lightgray")
        controls.pack(fill="x", pady=5)

        tk.Label(controls, text="Name:", bg="lightgray").pack(side="left")
        self.name_var = tk.StringVar(value=self.child_name)
        tk.Entry(controls, textvariable=self.name_var, width=10).pack(side="left", padx=5)

        tk.Label(controls, text="Status:", bg="lightgray").pack(side="left", padx=(10, 0))
        self.status_var = tk.StringVar(value="Ready")
        tk.Label(controls, textvariable=self.status_var, bg="lightgray", fg="darkgreen").pack(side="left", padx=5)

        buttons = tk.Frame(parent, bg="lightgray")
        buttons.pack(fill="x", pady=5)

        if self.audio and self.whisper_model:
            self.listen_btn = tk.Button(buttons, text="Listen", command=self.toggle_listening, bg="lightblue")
            self.listen_btn.pack(side="left", padx=2)

        tk.Button(buttons, text="Test Server", command=self.test_server, bg="lightcoral").pack(side="left", padx=2)

        emotion_defs = [
            ("Happy :)", "lightyellow"),
            ("Excited :D", "lightpink"),
            ("Think…", "lightcyan"),
            ("Listen |", "lightblue"),
            ("Confused ?", "wheat"),
        ]
        for emo, color in emotion_defs:
            tk.Button(
                buttons,
                text=emo,
                bg=color,
                command=lambda e=emo: self.set_emotion(e),
            ).pack(side="left", padx=1)

    def _build_chat(self, parent):
        chat_frame = tk.Frame(parent, bg="lightgray")
        chat_frame.pack(fill="both", expand=True, pady=5)

        tk.Label(chat_frame, text="Conversation:", bg="lightgray").pack(anchor="w")

        self.chat_text = tk.Text(
            chat_frame, height=8, wrap="word", bg="white", fg="black", state="disabled", bd=2
        )
        self.chat_text.pack(fill="both", expand=True)

        input_frame = tk.Frame(chat_frame, bg="lightgray")
        input_frame.pack(fill="x", pady=2)

        self.message_var = tk.StringVar()
        tk.Entry(input_frame, textvariable=self.message_var, bg="white").pack(
            side="left", fill="x", expand=True, padx=(0, 5)
        )
        tk.Button(input_frame, text="Send", bg="lightgreen", command=self.send_message).pack(side="right")

        tk.Label(parent, text="Press Enter to send messages", bg="lightgray", fg="gray").pack(pady=2)

    # ═══════════ Face Rendering ═══════════
    def draw_face(self, emotion):
        """Render eyes according to emotion on the canvas."""
        cv = self.face_canvas
        cv.delete("all")

        # geometry helpers
        w, h = 200, 100
        eye_w, eye_h = 40, 40
        left_x = w * 0.3 - eye_w / 2
        right_x = w * 0.7 - eye_w / 2
        y = h * 0.5 - eye_h / 2

        def open_eye(x):
            cv.create_oval(x, y, x + eye_w, y + eye_h, fill=CYAN, outline=CYAN)

        def closed_eye(x):
            cv.create_rectangle(x, y + eye_h / 2 - 2, x + eye_w, y + eye_h / 2 + 2, fill=CYAN, outline=CYAN)

        if "Happy" in emotion or "Listen" in emotion:
            open_eye(left_x)
            open_eye(right_x)
        elif "Excited" in emotion:
            # larger eyes
            eye_h2 = eye_w2 = 55
            cv.create_oval(left_x - 7, y - 7, left_x - 7 + eye_w2, y - 7 + eye_h2, fill=CYAN, outline=CYAN)
            cv.create_oval(right_x - 7, y - 7, right_x - 7 + eye_w2, y - 7 + eye_h2, fill=CYAN, outline=CYAN)
        elif "Think" in emotion:
            # eyes looking up (offset y)
            cv.create_oval(left_x, y - 8, left_x + eye_w, y - 8 + eye_h, fill=CYAN, outline=CYAN)
            cv.create_oval(right_x, y - 8, right_x + eye_w, y - 8 + eye_h, fill=CYAN, outline=CYAN)
        elif "Confused" in emotion:
            # one open, one half closed
            open_eye(left_x)
            closed_eye(right_x)
        else:
            # neutral closed
            closed_eye(left_x)
            closed_eye(right_x)

    # ═══════════ Blinking ═══════════
    def schedule_blink(self):
        delay = random.randint(3000, 6000)  # 3-6 s
        self._blink_job = self.root.after(delay, self._blink)

    def _blink(self):
        # Close eyes quickly then reopen
        if "Listen" not in self.current_emotion:  # don’t blink while listening
            self.draw_face("BLINK")
            self.root.after(150, lambda: self.draw_face(self.current_emotion))
        self.schedule_blink()

    # ═══════════  Chat helpers  ═══════════
    def update_status(self, text):
        self.status_var.set(text)
        self.root.update_idletasks()

    def add_to_chat(self, speaker, message):
        self.chat_text.config(state="normal")
        ts = datetime.now().strftime("%H:%M")
        self.chat_text.insert("end", f"[{ts}] {speaker}: {message}\n\n")
        self.chat_text.config(state="disabled")
        self.chat_text.see("end")

    # ═══════════  Emotion setter  ═══════════
    def set_emotion(self, emotion_text):
        self.current_emotion = emotion_text
        self.emotion_label.config(text=f"Neo is {emotion_text}")
        # background colour sync
        colour_map = {
            "Happy": "lightyellow",
            "Excited": "lightpink",
            "Think": "lightcyan",
            "Listen": "lightblue",
            "Confused": "wheat",
        }
        for k, col in colour_map.items():
            if k in emotion_text:
                self.emotion_frame.config(bg=col)
                self.emotion_label.config(bg=col)
                break
        else:
            self.emotion_frame.config(bg="lightgray")
            self.emotion_label.config(bg="lightgray")
        self.draw_face(emotion_text)

    # ═══════════  Message flow  ═══════════
    def send_message(self):
        msg = self.message_var.get().strip()
        if not msg:
            return
        self.message_var.set("")
        child_name = self.name_var.get() or "friend"
        self.add_to_chat(child_name, msg)
        self.process_message(msg, child_name)

    def process_message(self, msg, child_name):
        self.update_status("Thinking…")
        self.set_emotion("Think…")

        def worker():
            try:
                r = requests.post(
                    f"{self.server_url}/chat/text",
                    json={"message": msg, "child_name": child_name},
                    timeout=5,
                )
                response_text = r.json().get("response", "I got your message!") if r.status_code == 200 else f"Server error: {r.status_code}"
            except requests.exceptions.ConnectionError:
                response_text = "I can't connect to my knowledge server, but I'm here to chat with you!"
            except Exception as e:
                response_text = f"Connection problem: {e}"[:80]

            # simple sentiment → emotion mapping
            lowered = response_text.lower()
            if any(w in lowered for w in ("great", "awesome", "amazing")):
                emo = "Excited :D"
            elif any(w in lowered for w in ("confused", "sorry", "not sure")):
                emo = "Confused ?"
            else:
                emo = "Happy :)"

            self.root.after(0, lambda: self.handle_response(response_text, emo))

        threading.Thread(target=worker, daemon=True).start()

    def handle_response(self, text, emotion):
        self.add_to_chat("Neo", text)
        self.set_emotion(emotion)
        self.update_status("Ready")
        if self.tts_engine:
            threading.Thread(target=lambda: self._speak(text), daemon=True).start()

    def _speak(self, txt):
        try:
            self.tts_engine.say(txt)
            self.tts_engine.runAndWait()
        except Exception as e:
            print(f"Speech error: {e}")

    # ═══════════  Voice I/O (unchanged)  ═══════════
    def toggle_listening(self):
        if not self.audio or not self.whisper_model:
            messagebox.showwarning("Audio", "Audio not available")
            return
        if self.is_listening:
            self.stop_listening()
        else:
            self.start_listening()

    def start_listening(self):
        self.is_listening = True
        self.listen_btn.config(text="Stop", bg="lightcoral")
        self.update_status("Listening…")
        self.set_emotion("Listen |")

        def record():
            try:
                stream = self.audio.open(
                    format=pyaudio.paInt16,
                    channels=1,
                    rate=16000,
                    input=True,
                    frames_per_buffer=1024,
                )
                frames = []
                for _ in range(int(16000 * 3 / 1024)):
                    if not self.is_listening:
                        break
                    frames.append(stream.read(1024, exception_on_overflow=False))
                stream.stop_stream()
                stream.close()
            except Exception as e:
                print(f"Mic error: {e}")
                self.root.after(0, self.stop_listening)
                return

            if not frames or not self.is_listening:
                self.root.after(0, self.stop_listening)
                return

            import tempfile, wave
            with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
                wf = wave.open(tmp.name, "wb")
                wf.setnchannels(1)
                wf.setsampwidth(self.audio.get_sample_size(pyaudio.paInt16))
                wf.setframerate(16000)
                wf.writeframes(b"".join(frames))
                wf.close()
                path = tmp.name

            self.root.after(0, lambda: self.update_status("Processing…"))
            try:
                text = self.whisper_model.transcribe(path)["text"].strip()
            except Exception as e:
                print(f"Whisper error: {e}")
                text = ""
            if text:
                child_name = self.name_var.get() or "friend"
                self.root.after(0, lambda: self.add_to_chat(child_name, text))
                self.root.after(0, lambda: self.process_message(text, child_name))
            self.root.after(0, self.stop_listening)

        threading.Thread(target=record, daemon=True).start()

    def stop_listening(self):
        self.is_listening = False
        if hasattr(self, "listen_btn"):
            self.listen_btn.config(text="Listen", bg="lightblue")
        self.update_status("Ready")
        self.set_emotion("Happy :)")

    # ═══════════  Utils  ═══════════
    def test_server(self):
        def check():
            try:
                r = requests.get(f"{self.server_url}/health", timeout=3)
                if r.status_code == 200:
                    self.root.after(0, lambda: messagebox.showinfo("Server Test", "✅ Server connected!"))
                else:
                    self.root.after(0, lambda: messagebox.showwarning("Server Test", f"❌ Status: {r.status_code}"))
            except Exception as e:
                self.root.after(0, lambda: messagebox.showerror("Server Test", f"❌ {e}"))
        threading.Thread(target=check, daemon=True).start()

    # ═══════════  Run  ═══════════
    def run(self):
        self.add_to_chat("Neo", f"Hello {self.child_name}! I'm running in minimal mode – with eyes now!")
        self.root.mainloop()


# ═══════════ Entry Point ═══════════
if __name__ == "__main__":
    try:
        UltraMinimalNeoMind().run()
    except Exception as exc:
        print(f"❌ Failed: {exc}")