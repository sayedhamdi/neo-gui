#!/usr/bin/env python3
"""
NeoMind Ultra Minimal - X11 Safe Version
Avoids all font rendering issues
"""

import os
import sys
import warnings
import threading
from datetime import datetime

# Suppress everything
warnings.filterwarnings("ignore")
os.environ['ALSA_SUPPRESS_ERRORS'] = '1'
os.environ['PYTHONWARNINGS'] = 'ignore'

# Minimal imports
import tkinter as tk
from tkinter import messagebox
import requests

print("🧠 NeoMind Ultra Minimal - Starting...")

# Check what's available
has_audio = False
has_whisper = False
has_tts = False

try:
    import pyaudio
    import webrtcvad
    has_audio = True
    print("✅ Audio available")
except:
    print("⚠️ Audio not available")

try:
    import whisper
    has_whisper = True
    print("✅ Whisper available") 
except:
    print("⚠️ Whisper not available")

try:
    import pyttsx3
    has_tts = True
    print("✅ TTS available")
except:
    print("⚠️ TTS not available")

class UltraMinimalNeoMind:
    """Ultra minimal version that definitely works"""
    
    def __init__(self):
        self.child_name = "friend"
        self.server_url = "http://localhost:5000"
        self.current_emotion = "happy"
        self.is_listening = False
        
        # Initialize components
        self.whisper_model = None
        self.tts_engine = None
        self.audio = None
        
        self.init_components()
        self.create_gui()
    
    def init_components(self):
        """Initialize components safely"""
        # Whisper
        if has_whisper:
            try:
                print("Loading Whisper...")
                self.whisper_model = whisper.load_model("tiny.en")
                print("Whisper loaded")
            except Exception as e:
                print(f"Whisper failed: {e}")
        
        # TTS
        if has_tts:
            try:
                self.tts_engine = pyttsx3.init()
                self.tts_engine.setProperty('rate', 150)
            except Exception as e:
                print(f"TTS failed: {e}")
        
        # Audio
        if has_audio:
            try:
                # Suppress ALSA during init
                import contextlib
                with open(os.devnull, 'w') as devnull:
                    with contextlib.redirect_stderr(devnull):
                        self.audio = pyaudio.PyAudio()
            except Exception as e:
                print(f"Audio failed: {e}")
    
    def create_gui(self):
        """Create ultra-simple GUI"""
        self.root = tk.Tk()
        
        # Use only default system font - no custom fonts!
        self.root.option_add("*Font", "TkDefaultFont")
        
        self.root.title("NeoMind Minimal")
        self.root.geometry("600x400")
        self.root.configure(bg='lightgray')
        
        # Center window
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - 300
        y = (self.root.winfo_screenheight() // 2) - 200
        self.root.geometry(f"600x400+{x}+{y}")
        
        # Create widgets with ONLY default fonts
        self.create_widgets()
        
        # Bindings
        self.root.bind('<Return>', lambda e: self.send_message())
        
        print("🚀 GUI created successfully")
    
    def create_widgets(self):
        """Create widgets using only default system fonts"""
        # Main frame
        main = tk.Frame(self.root, bg='lightgray')
        main.pack(fill='both', expand=True, padx=10, pady=10)
        
        # Title - NO custom font, use default
        title = tk.Label(main, text="NeoMind AI Companion", bg='lightgray', fg='darkblue')
        title.pack(pady=5)
        
        # Emotion display - simple text only
        self.emotion_frame = tk.Frame(main, bg='lightyellow', relief='ridge', bd=2)
        self.emotion_frame.pack(pady=5)
        
        self.emotion_display = tk.Label(
            self.emotion_frame, 
            text="Neo is Happy :)",
            bg='lightyellow',
            fg='black',
            padx=20,
            pady=10
        )
        self.emotion_display.pack()
        
        # Controls frame
        controls = tk.Frame(main, bg='lightgray')
        controls.pack(fill='x', pady=5)
        
        # Child name
        tk.Label(controls, text="Name:", bg='lightgray').pack(side='left')
        self.name_var = tk.StringVar(value=self.child_name)
        name_entry = tk.Entry(controls, textvariable=self.name_var, width=10)
        name_entry.pack(side='left', padx=5)
        
        # Status
        tk.Label(controls, text="Status:", bg='lightgray').pack(side='left', padx=(10,0))
        self.status_var = tk.StringVar(value="Ready")
        status_label = tk.Label(controls, textvariable=self.status_var, bg='lightgray', fg='darkgreen')
        status_label.pack(side='left', padx=5)
        
        # Buttons frame
        buttons = tk.Frame(main, bg='lightgray')
        buttons.pack(fill='x', pady=5)
        
        # Audio button (if available)
        if self.audio and self.whisper_model:
            self.listen_btn = tk.Button(
                buttons,
                text="Listen",
                command=self.toggle_listening,
                bg='lightblue',
                relief='raised'
            )
            self.listen_btn.pack(side='left', padx=2)
        
        # Server test button
        tk.Button(
            buttons,
            text="Test Server",
            command=self.test_server,
            bg='lightcoral',
            relief='raised'
        ).pack(side='left', padx=2)
        
        # Emotion buttons - simple text only
        emotions = [
            ("Happy :)", "lightyellow"),
            ("Excited :D", "lightpink"), 
            ("Think...", "lightcyan"),
            ("Listen |", "lightblue"),
            ("Confused ?", "wheat")
        ]
        
        for emotion, color in emotions:
            tk.Button(
                buttons,
                text=emotion,
                command=lambda e=emotion: self.set_emotion(e),
                bg=color,
                relief='raised'
            ).pack(side='left', padx=1)
        
        # Chat area
        chat_frame = tk.Frame(main, bg='lightgray')
        chat_frame.pack(fill='both', expand=True, pady=5)
        
        tk.Label(chat_frame, text="Conversation:", bg='lightgray').pack(anchor='w')
        
        # Text area - using default font only
        self.chat_text = tk.Text(
            chat_frame,
            height=8,
            wrap='word',
            bg='white',
            fg='black',
            state='disabled',
            relief='sunken',
            bd=2
        )
        self.chat_text.pack(fill='both', expand=True, pady=2)
        
        # Input area
        input_frame = tk.Frame(chat_frame, bg='lightgray')
        input_frame.pack(fill='x', pady=2)
        
        self.message_var = tk.StringVar()
        self.message_entry = tk.Entry(
            input_frame,
            textvariable=self.message_var,
            bg='white'
        )
        self.message_entry.pack(side='left', fill='x', expand=True, padx=(0,5))
        self.message_entry.focus_set()
        
        tk.Button(
            input_frame,
            text="Send",
            command=self.send_message,
            bg='lightgreen',
            relief='raised'
        ).pack(side='right')
        
        # Footer
        tk.Label(
            main,
            text="Press Enter to send messages",
            bg='lightgray',
            fg='gray'
        ).pack(pady=2)
    
    def set_emotion(self, emotion_text):
        """Set emotion display"""
        try:
            self.emotion_display.config(text=f"Neo is {emotion_text}")
            
            # Change background color based on emotion
            if "Happy" in emotion_text:
                color = 'lightyellow'
            elif "Excited" in emotion_text:
                color = 'lightpink'
            elif "Think" in emotion_text:
                color = 'lightcyan'
            elif "Listen" in emotion_text:
                color = 'lightblue'
            elif "Confused" in emotion_text:
                color = 'wheat'
            else:
                color = 'lightgray'
            
            self.emotion_display.config(bg=color)
            self.emotion_frame.config(bg=color)
            
        except Exception as e:
            print(f"Emotion error: {e}")
    
    def update_status(self, text):
        """Update status text"""
        try:
            self.status_var.set(text)
            self.root.update_idletasks()
        except Exception as e:
            print(f"Status error: {e}")
    
    def add_to_chat(self, speaker, message):
        """Add message to chat"""
        try:
            self.chat_text.config(state='normal')
            
            timestamp = datetime.now().strftime("%H:%M")
            full_message = f"[{timestamp}] {speaker}: {message}\n\n"
            
            self.chat_text.insert('end', full_message)
            self.chat_text.config(state='disabled')
            self.chat_text.see('end')
            
        except Exception as e:
            print(f"Chat error: {e}")
    
    def send_message(self):
        """Send message to Neo"""
        message = self.message_var.get().strip()
        if not message:
            return
        
        self.message_var.set("")
        child_name = self.name_var.get() or "friend"
        
        self.add_to_chat(child_name, message)
        self.process_message(message, child_name)
    
    def process_message(self, message, child_name):
        """Process message with Neo"""
        self.update_status("Thinking...")
        self.set_emotion("Think...")
        
        def background():
            try:
                # Try to contact server
                response = requests.post(
                    f"{self.server_url}/chat/text",
                    json={'message': message, 'child_name': child_name},
                    timeout=5
                )
                
                if response.status_code == 200:
                    neo_response = response.json().get('response', 'I got your message!')
                else:
                    neo_response = f"Server error: {response.status_code}"
                    
            except requests.exceptions.ConnectionError:
                neo_response = "I can't connect to my knowledge server, but I'm here to chat with you!"
            except Exception as e:
                neo_response = f"Connection problem: {str(e)[:50]}"
            
            # Determine emotion
            if any(word in neo_response.lower() for word in ['great', 'awesome', 'amazing']):
                emotion = "Excited :D"
            elif any(word in neo_response.lower() for word in ['confused', 'sorry', 'not sure']):
                emotion = "Confused ?"
            else:
                emotion = "Happy :)"
            
            # Update GUI
            self.root.after(0, lambda: self.handle_response(neo_response, emotion))
        
        threading.Thread(target=background, daemon=True).start()
    
    def handle_response(self, response, emotion):
        """Handle Neo's response"""
        self.add_to_chat("Neo", response)
        self.set_emotion(emotion)
        self.update_status("Ready")
        
        # Speak if available
        if self.tts_engine:
            def speak():
                try:
                    self.tts_engine.say(response)
                    self.tts_engine.runAndWait()
                except Exception as e:
                    print(f"Speech error: {e}")
            
            threading.Thread(target=speak, daemon=True).start()
    
    def toggle_listening(self):
        """Toggle voice listening"""
        if not self.audio or not self.whisper_model:
            messagebox.showwarning("Audio", "Audio not available")
            return
        
        if self.is_listening:
            self.stop_listening()
        else:
            self.start_listening()
    
    def start_listening(self):
        """Start voice listening"""
        self.is_listening = True
        self.listen_btn.config(text="Stop", bg='lightcoral')
        self.update_status("Listening...")
        self.set_emotion("Listen |")
        
        def listen():
            try:
                # Record audio
                stream = self.audio.open(
                    format=pyaudio.paInt16,
                    channels=1,
                    rate=16000,
                    input=True,
                    frames_per_buffer=1024
                )
                
                frames = []
                for _ in range(int(16000 * 3 / 1024)):  # 3 seconds
                    if not self.is_listening:
                        break
                    data = stream.read(1024, exception_on_overflow=False)
                    frames.append(data)
                
                stream.stop_stream()
                stream.close()
                
                if frames and self.is_listening:
                    # Save and transcribe
                    import tempfile
                    import wave
                    
                    temp_file = tempfile.mktemp(suffix='.wav')
                    with wave.open(temp_file, 'wb') as wf:
                        wf.setnchannels(1)
                        wf.setsampwidth(self.audio.get_sample_size(pyaudio.paInt16))
                        wf.setframerate(16000)
                        wf.writeframes(b''.join(frames))
                    
                    self.root.after(0, lambda: self.update_status("Processing..."))
                    
                    result = self.whisper_model.transcribe(temp_file)
                    text = result["text"].strip()
                    
                    if text and self.is_listening:
                        child_name = self.name_var.get() or "friend"
                        self.root.after(0, lambda: self.add_to_chat(child_name, text))
                        self.root.after(0, lambda: self.process_message(text, child_name))
                
                self.root.after(0, self.stop_listening)
                
            except Exception as e:
                print(f"Listening error: {e}")
                self.root.after(0, self.stop_listening)
        
        threading.Thread(target=listen, daemon=True).start()
    
    def stop_listening(self):
        """Stop listening"""
        self.is_listening = False
        if hasattr(self, 'listen_btn'):
            self.listen_btn.config(text="Listen", bg='lightblue')
        self.update_status("Ready")
        self.set_emotion("Happy :)")
    
    def test_server(self):
        """Test server connection"""
        def test():
            try:
                response = requests.get(f"{self.server_url}/health", timeout=3)
                if response.status_code == 200:
                    self.root.after(0, lambda: messagebox.showinfo(
                        "Server Test",
                        f"✅ Server connected!\n{self.server_url}"
                    ))
                else:
                    self.root.after(0, lambda: messagebox.showwarning(
                        "Server Test",
                        f"❌ Server error: {response.status_code}"
                    ))
            except Exception as e:
                self.root.after(0, lambda: messagebox.showerror(
                    "Server Test",
                    f"❌ Cannot connect:\n{e}"
                ))
        
        threading.Thread(target=test, daemon=True).start()
    
    def run(self):
        """Run the application"""
        try:
            # Welcome message
            self.add_to_chat("Neo", f"Hello {self.child_name}! I'm running in minimal mode. Let's chat!")
            
            print("🚀 Starting GUI...")
            self.root.mainloop()
            
        except Exception as e:
            print(f"GUI error: {e}")
            messagebox.showerror("Error", f"GUI failed: {e}")

def main():
    """Main entry point"""
    try:
        app = UltraMinimalNeoMind()
        app.run()
    except Exception as e:
        print(f"❌ Failed to start: {e}")
        import traceback
        traceback.print_exc()
    
    print("👋 NeoMind closed")

if __name__ == "__main__":
    main()