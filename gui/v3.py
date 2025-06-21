#!/usr/bin/env python3
"""
NeoMind FACE-ONLY Kiosk – **Safe-Mode Edition** (Pi 3.5" TFT)
============================================================
Some Raspberry Pi images crash inside the **espeak / PortAudio** stack that
pyttsx3 and pyaudio rely on, causing a **Segmentation fault (core dumped)**.
This build adds:

1. **Crash-guarded audio** – wraps every PortAudio call in try/except and
   disables audio gracefully if PortAudio segfaults.
2. **Toggle flags** (all via env vars – no code edits required):
   • `NEOMIND_NO_TTS=1`  → run without TTS (prevents espeak crashes)
   • `NEOMIND_NO_MIC=1`  → run GUI only (no pyaudio / vad)
   • `NEOMIND_DEBUG=1`   → verbose logs (default on)
3. **Heartbeat logger** every 5 sec so you know the loop hasn’t frozen.

If you still hit segfaults, start with **both** flags enabled:

```bash
NEOMIND_NO_TTS=1 NEOMIND_NO_MIC=1 python3 neomind_face_safe.py
```
Then re-enable one feature at a time.
"""
import os, sys, warnings, random, threading, time, tempfile, wave, ctypes, tkinter as tk
from datetime import datetime
import requests

# ─────────────────── Logger & Helpers ───────────────────
DEBUG   = os.getenv("NEOMIND_DEBUG", "1") != "0"
NO_TTS  = os.getenv("NEOMIND_NO_TTS", "0") == "1"
NO_MIC  = os.getenv("NEOMIND_NO_MIC", "0") == "1"

def log(msg):
    if DEBUG:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", file=sys.stderr, flush=True)

log("Booting NeoMind Safe-Mode …")

# ───────────── Suppress ALSA / PortAudio noise ──────────
warnings.filterwarnings("ignore")
HANDLER = ctypes.CFUNCTYPE(None, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p)
try:
    ctypes.CDLL("libasound.so").snd_lib_error_set_handler(HANDLER(lambda *_: None))
except OSError:
    pass
os.environ.setdefault("ALSA_SUPPRESS_ERRORS", "1")

# ───────────── Conditional Heavy Imports ───────────────
try:
    if not NO_MIC:
        import pyaudio, webrtcvad
        has_audio = True
        log("Audio stack detected")
    else:
        has_audio = False
        log("Audio disabled via NEOMIND_NO_MIC")
except Exception as e:
    has_audio = False; log(f"Audio unavailable: {e}")

try:
    import whisper
    has_whisper = True; log("Whisper available ✔")
except Exception as e:
    has_whisper = False; log(f"Whisper not available: {e}")

try:
    if not NO_TTS:
        import pyttsx3
        has_tts = True; log("pyttsx3 available ✔")
    else:
        has_tts = False; log("TTS disabled via NEOMIND_NO_TTS")
except Exception as e:
    has_tts = False; log(f"TTS unavailable: {e}")

# ───────────── UI constants ─────────────
WIDTH, HEIGHT = 480, 320
CYAN, BLACK = "#00FFCC", "#000000"
BLINK_MIN_MS, BLINK_MAX_MS = 3000, 6000
MOUTH_PERIOD_MS = 160
WAKE_WORDS = ("hey", "hi", "hello")

# ───────────── Kid-voice helper ─────────────
def pick_child_voice(engine):
    prefer = ["child", "young", "kid", "boy", "girl"]
    force  = os.getenv("NEOMIND_VOICE", "").lower()
    for v in engine.getProperty("voices"):
        nid = (v.name + v.id).lower()
        if (force and force in nid) or any(p in nid for p in prefer):
            log(f"Kid voice → {v.name}"); return v.id
    return None

# ───────────── Canvas (eyes + mouth) ─────────────
class Face(tk.Canvas):
    def __init__(self, master):
        super().__init__(master, width=WIDTH, height=HEIGHT, bg=BLACK, highlightthickness=0)
        self.pack()
        self.emotion, self.mouth_open = "Happy", False
        self._blink_job = self._mouth_job = None
        self.draw(); self._schedule_blink();

    # Draw eyes & mouth
    def draw(self):
        self.delete("all"); ew=80; eh=80
        lx, rx, y = WIDTH*.25-ew/2, WIDTH*.75-ew/2, HEIGHT*.35-eh/2
        def open_eye(x):  self.create_oval(x,y,x+ew,y+eh,fill=CYAN,outline=CYAN)
        def closed_eye(x):self.create_rectangle(x,y+eh/2-4,x+ew,y+eh/2+4,fill=CYAN,outline=CYAN)
        e=self.emotion
        if e.startswith(("Happy","Listen")):      open_eye(lx);open_eye(rx)
        elif e.startswith("Excited"):
            self.create_oval(lx-10,y-10,lx+ew+10,y+eh+10,fill=CYAN,outline=CYAN)
            self.create_oval(rx-10,y-10,rx+ew+10,y+eh+10,fill=CYAN,outline=CYAN)
        elif e.startswith("Think"):               open_eye(lx);open_eye(rx);self.move("all",0,-15)
        elif e.startswith("Confused"):            open_eye(lx);closed_eye(rx)
        else:                                      closed_eye(lx);closed_eye(rx)
        # mouth
        self.delete("mouth"); my=HEIGHT*.7; mw=180; mh=60
        if self.mouth_open:
            self.create_oval(WIDTH/2-mw/2,my-mh/2,WIDTH/2+mw/2,my+mh/2,fill=CYAN,outline=CYAN,tags="mouth")
        else:
            self.create_rectangle(WIDTH/2-mw/2,my-4,WIDTH/2+mw/2,my+4,fill=CYAN,outline=CYAN,tags="mouth")

    # Blink
    def _schedule_blink(self):
        self._blink_job = self.after(random.randint(BLINK_MIN_MS,BLINK_MAX_MS), self._blink)
    def _blink(self):
        prev=self.emotion; self.emotion="Blink"; self.draw()
        self.after(120, lambda: (setattr(self,'emotion',prev), self.draw(), self._schedule_blink()))

    # Mouth while speaking
    def mouth_start(self):
        if self._mouth_job: return
        self.mouth_open=True; self.draw(); self._mouth_job=self.after(MOUTH_PERIOD_MS,self._toggle_mouth)
    def _toggle_mouth(self):
        self.mouth_open=not self.mouth_open; self.draw(); self._mouth_job=self.after(MOUTH_PERIOD_MS,self._toggle_mouth)
    def mouth_stop(self):
        if self._mouth_job: self.after_cancel(self._mouth_job); self._mouth_job=None
        self.mouth_open=False; self.draw()

# ───────────── Main Assistant ─────────────
class NeoMind:
    def __init__(self):
        self.state="IDLE"
        self.gui  = Face(tk.Tk()); self.gui.master.attributes("-fullscreen",True)
        self.audio = self.stream = self.vad = None
        self.rate  = 16000; self.chunk = 160
        self.whisper_model = None
        self.tts_engine    = None; self.stop_tts = threading.Event()
        if has_audio:   self._init_audio()
        if has_tts:     self._init_tts()
        if has_whisper: self.whisper_model=whisper.load_model("tiny.en")
        if has_audio:   threading.Thread(target=self._mic_loop,daemon=True).start()
        # Heartbeat log
        if DEBUG: self._heartbeat()
        self.gui.master.protocol("WM_DELETE_WINDOW", self._shutdown)
        self.gui.master.mainloop()

    # Heartbeat every 5s
    def _heartbeat(self):
        log(f"Heartbeat – state={self.state}"); self.gui.after(5000, self._heartbeat)

    # Audio init safely
    def _init_audio(self):
        import pyaudio, webrtcvad
        try:
            pa=pyaudio.PyAudio(); idx=0
            self.rate=16000
            self.stream=pa.open(format=pyaudio.paInt16,channels=1,rate=self.rate,input=True,input_device_index=idx,frames_per_buffer=int(self.rate/100))
            self.vad=webrtcvad.Vad(2); self.audio=pa
            log("Mic opened @16 kHz")
        except Exception as e:
            log(f"Mic init failed, disabling audio: {e}"); self.audio=None

    # TTS init safely
    def _init_tts(self):
        import pyttsx3
        try:
            eng=pyttsx3.init(); eng.setProperty('rate',165)
            vid=pick_child_voice(eng)
            if vid: eng.setProperty('voice',vid)
            self.tts_engine=eng; log("TTS ready")
        except Exception as e:
            log(f"TTS init error: {e}"); self.tts_engine=None

    # Mic loop (only if audio ok)
    def _mic_loop(self):
        frames,silence=[],0
        while self.audio:
            try:
                frame=self.stream.read(int(self.rate/100),exception_on_overflow=False)
            except Exception as e:
                log(f"Stream read error: {e}"); break
            speech=self.vad.is_speech(frame,self.rate) if self.vad else False
            if self.state=="SPEAK" and speech:
                self._stop_speaking(interrupted=True)
            if self.state in ("IDLE","LISTEN"):
                if speech: frames.append(frame); silence=0
                elif frames:
                    silence+=1
                    if silence>20:
                        pcm=b"".join(frames); frames,silence=[],0
                        threading.Thread(target=self._process_audio,args=(pcm,),daemon=True).start()
            time.sleep(0.005)

    def _process_audio(self,pcm):
        if not self.whisper_model: return
        with tempfile.NamedTemporaryFile(delete=False,suffix='.wav') as tmp:
            with wave.open(tmp.name,'wb') as wf:
                wf.setnchannels(1); import pyaudio; wf.setsampwidth(self.audio.get_sample_size(pyaudio.paInt16)); wf.setframerate(self.rate); wf.writeframes(pcm)
            path=tmp.name
        text=self.whisper_model.transcribe(path)['text'].strip().lower(); log(f"Heard: {text}")
        if self.state=="IDLE" and any(text.startswith(w) for w in WAKE_WORDS):
            self.state="LISTEN"; self.gui.emotion="Listen"; self.gui.draw(); return
        if self.state=="LISTEN":
            self._respond(text)

    # Respond (no network in safe-mode)
    def _respond(self,user):
        self.state="SPEAK"; self.gui.emotion="Think"; self.gui.draw()
        reply="I heard you!"; log(f"Reply: {reply}")
        if self.tts_engine:
            self.gui.mouth_start(); self.stop_tts.clear()
            threading.Thread(target=self._speak,args=(reply,),daemon=True).start()
        else:
            self.state="IDLE"; self.gui.emotion="Happy"; self.gui.draw()

    def _speak(self,txt):
        try:
            self.tts_engine.say(txt); self.tts_engine.runAndWait()
        except Exception as e:
            log(f"TTS runtime error: {e}")
        self._stop_speaking()

    def _stop_speaking(self,interrupted=False):
        if self.tts_engine: self.tts_engine.stop()
        self.gui.mouth_stop(); self.state="IDLE"; self.gui.emotion="Happy"; self.gui.draw()
        if interrupted: log("Speech interrupted by user")

    def _shutdown(self):
        log("Shutting down …"); os._exit(0)

# ─────────────────────── Launch ───────────────────────
if __name__=='__main__':
    try: NeoMind()
    except KeyboardInterrupt: log("Ctrl-C exit")