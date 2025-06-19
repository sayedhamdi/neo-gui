#!/bin/bash

# Complete NeoMind Setup from Scratch
# Creates everything needed for emotional AI companion

set -e

echo "🧠 Complete NeoMind Setup"
echo "========================="
echo "This will create a complete NeoMind system with:"
echo "  • Emotional GUI with 8 emotions"
echo "  • Voice input/output"
echo "  • Knowledge graph integration"
echo "  • Text chat interface"
echo ""

# Get setup location
read -p "📁 Where do you want to install NeoMind? (default: $HOME/neomind): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-"$HOME/neomind"}

echo "📍 Installing to: $INSTALL_DIR"

# Create main directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📦 Setting up directory structure..."

# Create subdirectories
mkdir -p {gui,server,config,logs,temp}

echo "🐍 Creating Python virtual environment..."
python3 -m venv neomind_env

# Activate environment
source neomind_env/bin/activate

echo "⬆️ Upgrading pip..."
pip install --upgrade pip setuptools wheel

echo "📚 Installing core dependencies..."
pip install requests pillow numpy python-dotenv

echo "🎤 Installing audio dependencies (optional)..."
pip install pyaudio webrtcvad || echo "⚠️ Audio packages failed - will work in text mode"

echo "🧠 Installing AI dependencies (this may take a while)..."
pip install openai-whisper pyttsx3 || echo "⚠️ AI packages failed - limited functionality"

echo "🔥 Installing PyTorch (CPU version)..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu || echo "⚠️ PyTorch failed - Whisper may not work"

# Create requirements file
cat > requirements.txt << 'EOF'
# NeoMind Complete Requirements
requests>=2.28.0
pillow>=9.0.0
numpy>=1.21.0
python-dotenv>=1.0.0

# Audio processing
pyaudio>=0.2.11
webrtcvad>=2.0.10

# AI models
openai-whisper>=20231117
torch>=2.0.0
torchvision>=0.15.0
torchaudio>=2.0.0
pyttsx3>=2.90
EOF

echo "⚙️ Creating configuration files..."

# Main configuration
cat > config/.env << 'EOF'
# NeoMind Configuration
CHILD_NAME=friend
NEOMIND_SERVER=http://localhost:5000
WHISPER_MODEL=tiny.en
VOICE_RATE=180
VOICE_VOLUME=0.9
WINDOW_WIDTH=900
WINDOW_HEIGHT=650
EOF

# Create the complete GUI application
echo "🎨 Creating NeoMind GUI application..."
cat > gui/neomind_gui.py << 'EOFILE'
#!/usr/bin/env python3
"""
NeoMind - Complete AI Companion with Emotions
Desktop version with full GUI interface
"""

import asyncio
import json
import logging
import os
import queue
import threading
import time
import wave
import warnings
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any, List
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import requests
import tempfile
import sys

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

# Suppress warnings
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", message=".*weights_only.*")
os.environ['ALSA_SUPPRESS_ERRORS'] = '1'
os.environ['PYTHONWARNINGS'] = 'ignore'

# Audio processing
try:
    import pyaudio
    import webrtcvad
    AUDIO_AVAILABLE = True
except ImportError:
    AUDIO_AVAILABLE = False

import numpy as np

# AI models
try:
    import whisper
    WHISPER_AVAILABLE = True
except ImportError:
    WHISPER_AVAILABLE = False

try:
    import pyttsx3
    TTS_AVAILABLE = True
except ImportError:
    TTS_AVAILABLE = False

# Load environment variables
try:
    from dotenv import load_dotenv
    load_dotenv('../config/.env')
except:
    pass

class Config:
    # Get from environment or use defaults
    CHILD_NAME = os.getenv('CHILD_NAME', 'friend')
    NEOMIND_SERVER = os.getenv('NEOMIND_SERVER', 'http://localhost:5000')
    WHISPER_MODEL = os.getenv('WHISPER_MODEL', 'tiny.en')
    VOICE_RATE = int(os.getenv('VOICE_RATE', 180))
    VOICE_VOLUME = float(os.getenv('VOICE_VOLUME', 0.9))
    WINDOW_WIDTH = int(os.getenv('WINDOW_WIDTH', 900))
    WINDOW_HEIGHT = int(os.getenv('WINDOW_HEIGHT', 650))
    
    # Audio settings
    SAMPLE_RATE = 16000
    CHUNK_SIZE = 1024
    CHANNELS = 1
    
    # Emotions
    EMOTIONS = {
        'happy': {'color': '#FFD700', 'emoji': '😊', 'desc': 'Happy'},
        'excited': {'color': '#FF6B6B', 'emoji': '🤩', 'desc': 'Excited'},
        'thinking': {'color': '#4ECDC4', 'emoji': '🤔', 'desc': 'Thinking'},
        'listening': {'color': '#45B7D1', 'emoji': '👂', 'desc': 'Listening'},
        'speaking': {'color': '#96CEB4', 'emoji': '💬', 'desc': 'Speaking'},
        'confused': {'color': '#FECA57', 'emoji': '😕', 'desc': 'Confused'},
        'neutral': {'color': '#95A5A6', 'emoji': '😐', 'desc': 'Neutral'},
        'sleeping': {'color': '#BDC3C7', 'emoji': '😴', 'desc': 'Sleeping'}
    }

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('../logs/neomind.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class EmotionalFace:
    """Neo's emotional face display"""
    
    def __init__(self, parent_frame):
        self.frame = parent_frame
        self.current_emotion = 'happy'
        self.create_widgets()
        
    def create_widgets(self):
        """Create face widgets"""
        # Face container
        self.face_frame = tk.Frame(
            self.frame, 
            bg='white', 
            relief='ridge', 
            bd=3,
            width=280,
            height=280
        )
        self.face_frame.pack(pady=10)
        self.face_frame.pack_propagate(False)
        
        # Emotion emoji
        self.emotion_label = tk.Label(
            self.face_frame,
            text="😊",
            font=("Arial", 64),
            bg='white',
            fg='black'
        )
        self.emotion_label.place(relx=0.5, rely=0.4, anchor='center')
        
        # Emotion name
        self.name_label = tk.Label(
            self.face_frame,
            text="Happy",
            font=("Arial", 14, "bold"),
            bg='white',
            fg='#2C3E50'
        )
        self.name_label.place(relx=0.5, rely=0.75, anchor='center')
        
    def set_emotion(self, emotion='happy'):
        """Set facial emotion"""
        emotion_data = Config.EMOTIONS.get(emotion, Config.EMOTIONS['happy'])
        
        try:
            self.emotion_label.config(
                text=emotion_data['emoji'],
                bg=emotion_data['color']
            )
            self.name_label.config(
                text=emotion_data['desc'],
                bg=emotion_data['color']
            )
            self.face_frame.config(bg=emotion_data['color'])
            
            self.current_emotion = emotion
            
        except Exception as e:
            logger.error(f"Error setting emotion: {e}")

class AudioProcessor:
    """Handle audio input/output"""
    
    def __init__(self):
        if AUDIO_AVAILABLE:
            try:
                self.audio = pyaudio.PyAudio()
            except Exception as e:
                logger.error(f"Audio init failed: {e}")
                raise
        else:
            raise Exception("Audio not available")
    
    def record_speech(self, duration=5.0):
        """Record speech from microphone"""
        if not AUDIO_AVAILABLE:
            return None
            
        frames = []
        
        try:
            stream = self.audio.open(
                format=pyaudio.paInt16,
                channels=Config.CHANNELS,
                rate=Config.SAMPLE_RATE,
                input=True,
                frames_per_buffer=Config.CHUNK_SIZE
            )
            
            logger.info(f"🎤 Recording for {duration} seconds...")
            
            for _ in range(int(Config.SAMPLE_RATE * duration / Config.CHUNK_SIZE)):
                data = stream.read(Config.CHUNK_SIZE, exception_on_overflow=False)
                frames.append(data)
            
            stream.stop_stream()
            stream.close()
            
            # Save to temp file
            temp_file = tempfile.mktemp(suffix='.wav')
            with wave.open(temp_file, 'wb') as wf:
                wf.setnchannels(Config.CHANNELS)
                wf.setsampwidth(self.audio.get_sample_size(pyaudio.paInt16))
                wf.setframerate(Config.SAMPLE_RATE)
                wf.writeframes(b''.join(frames))
            
            return temp_file
            
        except Exception as e:
            logger.error(f"Recording failed: {e}")
            return None

class SpeechProcessor:
    """Handle speech recognition and synthesis"""
    
    def __init__(self):
        self.whisper_model = None
        self.tts_engine = None
        
        # Initialize Whisper
        if WHISPER_AVAILABLE:
            try:
                logger.info("🧠 Loading Whisper model...")
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore")
                    self.whisper_model = whisper.load_model(Config.WHISPER_MODEL)
                logger.info("✅ Whisper model loaded")
            except Exception as e:
                logger.error(f"Whisper failed: {e}")
        
        # Initialize TTS
        if TTS_AVAILABLE:
            try:
                self.tts_engine = pyttsx3.init()
                self.tts_engine.setProperty('rate', Config.VOICE_RATE)
                self.tts_engine.setProperty('volume', Config.VOICE_VOLUME)
                
                # Try to set female voice
                voices = self.tts_engine.getProperty('voices')
                for voice in voices:
                    if 'female' in voice.name.lower():
                        self.tts_engine.setProperty('voice', voice.id)
                        break
                        
            except Exception as e:
                logger.error(f"TTS failed: {e}")
                self.tts_engine = None
    
    def transcribe_audio(self, audio_file):
        """Convert speech to text"""
        if not self.whisper_model:
            return "Hello Neo, this is a test message!"
        
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                result = self.whisper_model.transcribe(audio_file)
            text = result["text"].strip()
            logger.info(f"📝 Transcribed: {text}")
            return text
        except Exception as e:
            logger.error(f"Transcription failed: {e}")
            return None
    
    def speak_text(self, text):
        """Convert text to speech"""
        if not self.tts_engine:
            logger.info(f"🗣️ Would speak: {text}")
            return
        
        try:
            self.tts_engine.say(text)
            self.tts_engine.runAndWait()
        except Exception as e:
            logger.error(f"Speech failed: {e}")

class NeoMindConnector:
    """Connect to NeoMind knowledge graph server"""
    
    def __init__(self):
        self.server_url = Config.NEOMIND_SERVER
    
    def chat_with_neo(self, message, child_name):
        """Send message to Neo and get response"""
        try:
            payload = {
                'message': message,
                'child_name': child_name
            }
            
            response = requests.post(
                f"{self.server_url}/chat/text",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                return data.get('response', '')
            else:
                logger.error(f"Server error: {response.status_code}")
                return None
                
        except requests.exceptions.ConnectionError:
            return "I can't connect to my knowledge right now, but I'm still here to chat!"
        except requests.exceptions.Timeout:
            return "I'm thinking a bit slowly, but I'm here to help!"
        except Exception as e:
            logger.error(f"Chat failed: {e}")
            return None
    
    def health_check(self):
        """Check if server is running"""
        try:
            response = requests.get(f"{self.server_url}/health", timeout=5)
            return response.status_code == 200
        except:
            return False

class NeoMindGUI:
    """Main NeoMind GUI application"""
    
    def __init__(self):
        self.setup_window()
        self.setup_variables()
        self.setup_components()
        self.create_widgets()
        self.setup_bindings()
        
        logger.info("🧠 NeoMind GUI initialized")
    
    def setup_window(self):
        """Setup main window"""
        self.root = tk.Tk()
        self.root.title("🧠 NeoMind - AI Companion")
        self.root.geometry(f"{Config.WINDOW_WIDTH}x{Config.WINDOW_HEIGHT}")
        self.root.configure(bg='#2C3E50')
        
        # Center window
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - (Config.WINDOW_WIDTH // 2)
        y = (self.root.winfo_screenheight() // 2) - (Config.WINDOW_HEIGHT // 2)
        self.root.geometry(f"{Config.WINDOW_WIDTH}x{Config.WINDOW_HEIGHT}+{x}+{y}")
    
    def setup_variables(self):
        """Setup GUI variables"""
        self.child_name = tk.StringVar(value=Config.CHILD_NAME)
        self.status_text = tk.StringVar(value="Ready to chat!")
        self.is_listening = False
        self.conversation_history = []
        
    def setup_components(self):
        """Setup audio, speech, and server components"""
        # Audio processor
        self.audio_processor = None
        if AUDIO_AVAILABLE:
            try:
                self.audio_processor = AudioProcessor()
            except Exception as e:
                logger.warning(f"Audio setup failed: {e}")
        
        # Speech processor
        self.speech_processor = None
        if WHISPER_AVAILABLE or TTS_AVAILABLE:
            try:
                self.speech_processor = SpeechProcessor()
            except Exception as e:
                logger.warning(f"Speech setup failed: {e}")
        
        # Server connector
        self.server_connector = NeoMindConnector()
    
    def create_widgets(self):
        """Create all GUI widgets"""
        # Main container
        main_frame = tk.Frame(self.root, bg='#2C3E50')
        main_frame.pack(fill='both', expand=True, padx=20, pady=20)
        
        # Title
        title_label = tk.Label(
            main_frame,
            text="🧠 NeoMind AI Companion",
            font=("Arial", 20, "bold"),
            fg="#ECF0F1",
            bg="#2C3E50"
        )
        title_label.pack(pady=(0, 20))
        
        # Top section
        top_frame = tk.Frame(main_frame, bg='#2C3E50')
        top_frame.pack(fill='x', pady=(0, 20))
        
        # Left - Neo's face
        face_container = tk.LabelFrame(
            top_frame,
            text="Neo's Emotions",
            font=("Arial", 12, "bold"),
            bg='#34495E',
            fg='white',
            bd=2,
            relief='groove'
        )
        face_container.pack(side='left', padx=(0, 20))
        
        self.face = EmotionalFace(face_container)
        
        # Right - Controls
        controls_container = tk.LabelFrame(
            top_frame,
            text="Controls & Settings",
            font=("Arial", 12, "bold"),
            bg='#34495E',
            fg='white',
            bd=2,
            relief='groove'
        )
        controls_container.pack(side='right', fill='both', expand=True)
        
        controls_frame = tk.Frame(controls_container, bg='#34495E')
        controls_frame.pack(fill='both', expand=True, padx=15, pady=15)
        
        # Child name setting
        name_frame = tk.Frame(controls_frame, bg='#34495E')
        name_frame.pack(fill='x', pady=(0, 15))
        
        tk.Label(
            name_frame,
            text="Child's Name:",
            font=("Arial", 11),
            bg='#34495E',
            fg='white'
        ).pack(side='left')
        
        name_entry = tk.Entry(
            name_frame,
            textvariable=self.child_name,
            font=("Arial", 11),
            width=15,
            relief='sunken',
            bd=2
        )
        name_entry.pack(side='left', padx=(10, 0))
        
        # Status display
        status_frame = tk.Frame(controls_frame, bg='#34495E')
        status_frame.pack(fill='x', pady=(0, 15))
        
        tk.Label(
            status_frame,
            text="Status:",
            font=("Arial", 11),
            bg='#34495E',
            fg='white'
        ).pack(side='left')
        
        status_label = tk.Label(
            status_frame,
            textvariable=self.status_text,
            font=("Arial", 11, "bold"),
            bg='#34495E',
            fg='#1ABC9C'
        )
        status_label.pack(side='left', padx=(10, 0))
        
        # Control buttons
        button_frame = tk.Frame(controls_frame, bg='#34495E')
        button_frame.pack(fill='x', pady=15)
        
        self.listen_button = tk.Button(
            button_frame,
            text="🎤 Start Listening",
            command=self.toggle_listening,
            font=("Arial", 10, "bold"),
            bg='#3498DB',
            fg='white',
            relief='raised',
            bd=2,
            padx=15,
            pady=5
        )
        self.listen_button.pack(side='left', padx=(0, 15))
        
        test_button = tk.Button(
            button_frame,
            text="🔗 Test Server",
            command=self.test_server_connection,
            font=("Arial", 10, "bold"),
            bg='#E74C3C',
            fg='white',
            relief='raised',
            bd=2,
            padx=15,
            pady=5
        )
        test_button.pack(side='left')
        
        # Emotion test buttons
        emotion_container = tk.LabelFrame(
            controls_frame,
            text="Test Emotions",
            font=("Arial", 10),
            bg='#34495E',
            fg='white'
        )
        emotion_container.pack(fill='x', pady=15)
        
        emotion_frame = tk.Frame(emotion_container, bg='#34495E')
        emotion_frame.pack(padx=10, pady=10)
        
        # Create emotion buttons in grid
        emotions = list(Config.EMOTIONS.keys())
        for i, emotion in enumerate(emotions):
            row = i // 4
            col = i % 4
            
            emotion_data = Config.EMOTIONS[emotion]
            btn = tk.Button(
                emotion_frame,
                text=f"{emotion_data['emoji']} {emotion_data['desc']}",
                command=lambda e=emotion: self.set_emotion(e),
                font=("Arial", 8),
                bg=emotion_data['color'],
                fg='black',
                relief='raised',
                bd=1,
                padx=8,
                pady=3
            )
            btn.grid(row=row, column=col, padx=3, pady=3, sticky='ew')
        
        # Configure grid
        for i in range(4):
            emotion_frame.columnconfigure(i, weight=1)
        
        # Chat area
        chat_container = tk.LabelFrame(
            main_frame,
            text="Conversation with Neo",
            font=("Arial", 12, "bold"),
            bg='#34495E',
            fg='white',
            bd=2,
            relief='groove'
        )
        chat_container.pack(fill='both', expand=True, pady=(0, 20))
        
        chat_frame = tk.Frame(chat_container, bg='#34495E')
        chat_frame.pack(fill='both', expand=True, padx=15, pady=15)
        
        # Chat display
        self.chat_display = scrolledtext.ScrolledText(
            chat_frame,
            height=10,
            wrap=tk.WORD,
            font=("Arial", 10),
            bg='white',
            fg='black',
            state='disabled',
            relief='sunken',
            bd=2
        )
        self.chat_display.pack(fill='both', expand=True, pady=(0, 15))
        
        # Message input
        input_frame = tk.Frame(chat_frame, bg='#34495E')
        input_frame.pack(fill='x')
        
        self.message_entry = tk.Entry(
            input_frame,
            font=("Arial", 11),
            bg='white',
            fg='black',
            relief='sunken',
            bd=2
        )
        self.message_entry.pack(side='left', fill='x', expand=True, padx=(0, 15))
        
        send_button = tk.Button(
            input_frame,
            text="Send",
            command=self.send_text_message,
            font=("Arial", 10, "bold"),
            bg='#27AE60',
            fg='white',
            relief='raised',
            bd=2,
            padx=20,
            pady=5
        )
        send_button.pack(side='right')
        
        # Footer
        footer_frame = tk.Frame(main_frame, bg='#2C3E50')
        footer_frame.pack(fill='x')
        
        footer_text = "💡 Type messages or use voice • Ctrl+L: Listen • Ctrl+Q: Quit • Ctrl+T: Test Server"
        footer_label = tk.Label(
            footer_frame,
            text=footer_text,
            font=("Arial", 9),
            fg="#BDC3C7",
            bg="#2C3E50"
        )
        footer_label.pack()
    
    def setup_bindings(self):
        """Setup keyboard shortcuts"""
        self.root.bind('<Return>', lambda e: self.send_text_message())
        self.root.bind('<Control-l>', lambda e: self.toggle_listening())
        self.root.bind('<Control-q>', lambda e: self.root.quit())
        self.root.bind('<Control-t>', lambda e: self.test_server_connection())
        
        # Focus on message entry
        self.message_entry.focus_set()
    
    def set_emotion(self, emotion):
        """Set Neo's current emotion"""
        self.face.set_emotion(emotion)
        self.update_status(f"Neo is feeling {emotion}!")
    
    def update_status(self, message):
        """Update status display"""
        self.status_text.set(message)
        self.root.update_idletasks()
    
    def add_to_chat(self, speaker, message, emotion=None):
        """Add message to chat display"""
        self.chat_display.configure(state='normal')
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        if speaker == "Neo":
            prefix = f"[{timestamp}] 🧠 Neo"
            if emotion:
                prefix += f" ({emotion})"
            prefix += ": "
        else:
            child_name = self.child_name.get()
            prefix = f"[{timestamp}] 👶 {child_name}: "
        
        self.chat_display.insert(tk.END, prefix + message + "\n\n")
        self.chat_display.configure(state='disabled')
        self.chat_display.see(tk.END)
        
        # Store in history
        self.conversation_history.append({
            'timestamp': timestamp,
            'speaker': speaker,
            'message': message,
            'emotion': emotion
        })
    
    def send_text_message(self):
        """Send text message to Neo"""
        message = self.message_entry.get().strip()
        if not message:
            return
        
        self.message_entry.delete(0, tk.END)
        self.add_to_chat(self.child_name.get(), message)
        self.process_message(message)
    
    def process_message(self, message):
        """Process message and get Neo's response"""
        self.update_status("Neo is thinking...")
        self.set_emotion('thinking')
        
        # Process in background
        threading.Thread(
            target=self._process_message_background,
            args=(message,),
            daemon=True
        ).start()
    
    def _process_message_background(self, message):
        """Background message processing"""
        try:
            response = self.server_connector.chat_with_neo(
                message, 
                self.child_name.get()
            )
            
            if response:
                emotion = self.determine_response_emotion(response)
                self.root.after(0, self._handle_response, response, emotion)
            else:
                fallback = "I'm having trouble thinking right now, but I'm here to help!"
                self.root.after(0, self._handle_response, fallback, 'confused')
                
        except Exception as e:
            logger.error(f"Message processing failed: {e}")
            error_msg = "Oops! Something went wrong, but I'm still here!"
            self.root.after(0, self._handle_response, error_msg, 'confused')
    
    def _handle_response(self, response, emotion):
        """Handle Neo's response"""
        self.add_to_chat("Neo", response, emotion)
        self.set_emotion(emotion)
        self.update_status(f"Neo responded ({emotion})")
        
        # Speak if available
        if self.speech_processor and TTS_AVAILABLE:
            self.speak_response(response)
        else:
            self.update_status("Ready to chat!")
    
    def determine_response_emotion(self, response):
        """Determine emotion from response content"""
        response_lower = response.lower()
        
        if any(word in response_lower for word in ['exciting', 'amazing', 'wonderful', 'fantastic', 'wow']):
            return 'excited'
        elif any(word in response_lower for word in ['happy', 'great', 'awesome', 'love', 'fun']):
            return 'happy'
        elif any(word in response_lower for word in ['think', 'consider', 'maybe', 'perhaps', 'wondering']):
            return 'thinking'
        elif any(word in response_lower for word in ['sorry', 'confused', 'not sure', "don't know", 'unclear']):
            return 'confused'
        elif any(word in response_lower for word in ['tell', 'explain', 'say', 'talk', 'speaking']):
            return 'speaking'
        else:
            return 'happy'
    
    def speak_response(self, text):
        """Speak Neo's response"""
        def speak_background():
            try:
                self.root.after(0, lambda: self.set_emotion('speaking'))
                self.speech_processor.speak_text(text)
                self.root.after(0, lambda: self.update_status("Ready to chat!"))
                self.root.after(0, lambda: self.set_emotion('happy'))
            except Exception as e:
                logger.error(f"Speech failed: {e}")
                self.root.after(0, lambda: self.update_status("Ready to chat!"))
        
        threading.Thread(target=speak_background, daemon=True).start()
    
    def toggle_listening(self):
        """Toggle voice listening"""
        if not AUDIO_AVAILABLE or not self.audio_processor:
            messagebox.showwarning(
                "Audio Not Available",
                "Audio libraries not available.\nInstall with: pip install pyaudio webrtcvad"
            )
            return
        
        if self.is_listening:
            self.stop_listening()
        else:
            self.start_listening()
    
    def start_listening(self):
        """Start voice listening"""
        self.is_listening = True
        self.listen_button.configure(
            text="🔴 Stop Listening",
            bg='#E74C3C'
        )
        self.update_status("Listening for your voice...")
        self.set_emotion('listening')
        
        threading.Thread(target=self._listen_background, daemon=True).start()
    
    def stop_listening(self):
        """Stop voice listening"""
        self.is_listening = False
        self.listen_button.configure(
            text="🎤 Start Listening",
            bg='#3498DB'
        )
        self.update_status("Ready to chat!")
        self.set_emotion('neutral')
    
    def _listen_background(self):
        """Background voice listening"""
        try:
            if not self.speech_processor:
                return
            
            # Record audio
            audio_file = self.audio_processor.record_speech(duration=5.0)
            
            if audio_file and self.is_listening:
                self.root.after(0, lambda: self.update_status("Understanding what you said..."))
                self.root.after(0, lambda: self.set_emotion('thinking'))
                
                text = self.speech_processor.transcribe_audio(audio_file)
                
                if text and self.is_listening:
                    self.root.after(0, lambda: self.add_to_chat(self.child_name.get(), text))
                    self.root.after(0, lambda: self.process_message(text))
                
                self.root.after(0, self.stop_listening)
            else:
                self.root.after(0, self.stop_listening)
                
        except Exception as e:
            logger.error(f"Voice listening failed: {e}")
            self.root.after(0, self.stop_listening)
    
    def test_server_connection(self):
        """Test connection to NeoMind server"""
        def test_background():
            try:
                if self.server_connector.health_check():
                    self.root.after(0, lambda: messagebox.showinfo(
                        "Server Connection",
                        f"✅ Connected to NeoMind server!\n\nServer: {Config.NEOMIND_SERVER}\n\n"
                        "Your knowledge graph is ready!"
                    ))
                else:
                    self.root.after(0, lambda: messagebox.showwarning(
                        "Server Connection",
                        f"❌ Cannot connect to NeoMind server.\n\n"
                        f"Expected location: {Config.NEOMIND_SERVER}\n\n"
                        "Start your server with:\npython ../server/neomind_server.py"
                    ))
            except Exception as e:
                self.root.after(0, lambda: messagebox.showerror(
                    "Server Connection",
                    f"❌ Connection test failed:\n{e}"
                ))
        
        threading.Thread(target=test_background, daemon=True).start()
    
    def run(self):
        """Run the application"""
        try:
            # Welcome message
            self.add_to_chat("Neo", f"Hello {self.child_name.get()}! I'm Neo, your AI companion. I'm excited to learn and explore together!", "happy")
            self.set_emotion('happy')
            
            # Start main loop
            self.root.mainloop()
            
        except Exception as e:
            logger.error(f"GUI error: {e}")
            print(f"GUI Error: {e}")

def main():
    """Main entry point"""
    print("""
    ╔═══════════════════════════════════════╗
    ║         🧠 NEOMIND DESKTOP 🧠         ║
    ║      AI Companion with Emotions       ║
    ║                                       ║
    ║  🎤 Voice & Text • 😊 Emotions        ║
    ║  🧠 Knowledge Graph • 💬 Chat         ║
    ╚═══════════════════════════════════════╝
    """)
    
    # Check available features
    features = []
    if AUDIO_AVAILABLE:
        features.append("🎤 Voice Input")
    if WHISPER_AVAILABLE:
        features.append("🧠 Speech Recognition")
    if TTS_AVAILABLE:
        features.append("🗣️ Voice Output")
    
    features.extend(["💬 Text Chat", "😊 Emotions", "🔗 Server Integration"])
    
    print("Available features:")
    for feature in features:
        print(f"  ✅ {feature}")
    
    print(f"\n🔗 Connecting to: {Config.NEOMIND_SERVER}")
    print("📝 Make sure your knowledge graph server is running!")
    print("\n🚀 Starting NeoMind...")
    
    try:
        app = NeoMindGUI()
        app.run()
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
EOFILE

echo "🖥️ Creating sample NeoMind knowledge server..."
cat > server/neomind_server.py << 'EOFILE'
#!/usr/bin/env python3
"""
Sample NeoMind Knowledge Graph Server
This is a simple version - replace with your full Graphiti server
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Simple in-memory storage (replace with your Graphiti implementation)
conversations = {}

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'message': 'NeoMind server is running'
    })

@app.route('/chat/text', methods=['POST'])
def chat_text():
    """Handle text chat messages"""
    try:
        data = request.get_json()
        message = data.get('message', '')
        child_name = data.get('child_name', 'friend')
        
        logger.info(f"📨 Message from {child_name}: {message}")
        
        # Store conversation
        if child_name not in conversations:
            conversations[child_name] = []
        
        conversations[child_name].append({
            'timestamp': datetime.now().isoformat(),
            'message': message,
            'type': 'user'
        })
        
        # Generate simple response (replace with your Graphiti logic)
        response = generate_simple_response(message, child_name)
        
        conversations[child_name].append({
            'timestamp': datetime.now().isoformat(),
            'message': response,
            'type': 'neo'
        })
        
        logger.info(f"🤖 Neo responded to {child_name}: {response[:50]}...")
        
        return jsonify({
            'response': response,
            'child_name': child_name,
            'conversation_count': len(conversations[child_name]),
            'memories_used': 1  # Mock value
        })
        
    except Exception as e:
        logger.error(f"Chat error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

def generate_simple_response(message, child_name):
    """Generate a simple response (replace with your Graphiti implementation)"""
    message_lower = message.lower()
    
    # Simple keyword-based responses
    if any(word in message_lower for word in ['hello', 'hi', 'hey']):
        return f"Hello {child_name}! How are you doing today? What would you like to learn about?"
    
    elif any(word in message_lower for word in ['what', 'how', 'why', 'when', 'where']):
        return f"That's a great question, {child_name}! Let me think about that. What specifically interests you about this topic?"
    
    elif any(word in message_lower for word in ['math', 'numbers', 'calculate']):
        return f"I love math, {child_name}! Math is like solving fun puzzles. What math problem are you working on?"
    
    elif any(word in message_lower for word in ['science', 'experiment', 'discovery']):
        return f"Science is amazing, {child_name}! There's so much to discover. What scientific concept fascinates you?"
    
    elif any(word in message_lower for word in ['art', 'draw', 'create', 'paint']):
        return f"Art is wonderful for expressing creativity, {child_name}! What kind of art project are you thinking about?"
    
    elif any(word in message_lower for word in ['story', 'book', 'read']):
        return f"I love stories too, {child_name}! Stories help us learn about the world. What's your favorite type of story?"
    
    elif any(word in message_lower for word in ['game', 'play', 'fun']):
        return f"Playing and learning go great together, {child_name}! What kind of games do you enjoy?"
    
    else:
        return f"That's interesting, {child_name}! Tell me more about what you're thinking. I'm here to learn and explore with you!"

@app.route('/memories/search', methods=['POST'])
def search_memories():
    """Search memories (mock implementation)"""
    try:
        data = request.get_json()
        query = data.get('query', '')
        child_name = data.get('child_name', 'friend')
        
        # Mock memory search
        memories = []
        if child_name in conversations:
            for conv in conversations[child_name][-5:]:  # Last 5 conversations
                if query.lower() in conv['message'].lower():
                    memories.append({
                        'fact': conv['message'],
                        'timestamp': conv['timestamp'],
                        'relevance': 0.8
                    })
        
        return jsonify({
            'query': query,
            'child_name': child_name,
            'memories': memories,
            'count': len(memories)
        })
        
    except Exception as e:
        logger.error(f"Memory search error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    print("""
    🧠 NeoMind Knowledge Server (Sample)
    ===================================
    
    This is a simple server for testing.
    Replace with your full Graphiti implementation.
    
    Endpoints:
    - GET  /health         - Health check
    - POST /chat/text      - Text chat
    - POST /memories/search - Memory search
    """)
    
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
EOFILE

echo "📝 Creating startup scripts..."

# Main launcher
cat > start_neomind.sh << 'EOF'
#!/bin/bash

# NeoMind Complete Launcher

echo "🧠 Starting NeoMind System"
echo "=========================="

cd "$(dirname "$0")"

# Check if setup was completed
if [ ! -d "neomind_env" ]; then
    echo "❌ Setup not completed!"
    echo "Run: ./setup_neomind.sh first"
    exit 1
fi

# Activate environment
echo "🐍 Activating environment..."
source neomind_env/bin/activate

# Suppress audio warnings
export ALSA_SUPPRESS_ERRORS=1
export PYTHONWARNINGS=ignore

# Check server
echo "🔍 Checking NeoMind server..."
if curl -s "http://localhost:5000/health" > /dev/null 2>&1; then
    echo "✅ Server is running!"
else
    echo "⚠️  Server not detected. Starting sample server..."
    echo "   (Replace server/neomind_server.py with your Graphiti server)"
    
    # Start server in background
    cd server
    python neomind_server.py &
    SERVER_PID=$!
    cd ..
    
    echo "🔄 Waiting for server to start..."
    sleep 3
    
    # Check again
    if curl -s "http://localhost:5000/health" > /dev/null 2>&1; then
        echo "✅ Sample server started!"
        echo "   PID: $SERVER_PID"
    else
        echo "❌ Server failed to start"
        exit 1
    fi
fi

# Launch GUI
echo "🎨 Starting NeoMind GUI..."
cd gui
python neomind_gui.py 2>/dev/null

echo ""
echo "👋 NeoMind session ended"

# Cleanup server if we started it
if [ ! -z "$SERVER_PID" ]; then
    echo "🧹 Stopping sample server..."
    kill $SERVER_PID 2>/dev/null
fi
EOF

chmod +x start_neomind.sh

# Quick test script
cat > test_neomind.sh << 'EOF'
#!/bin/bash

# NeoMind Test Script

echo "🧪 NeoMind System Test"
echo "====================="

cd "$(dirname "$0")"

# Test 1: Environment
echo "1️⃣ Testing Python environment..."
if [ -d "neomind_env" ]; then
    echo "   ✅ Virtual environment exists"
    source neomind_env/bin/activate
    
    # Test imports
    python -c "
import tkinter as tk
import requests
import numpy as np
print('   ✅ Core packages work')
"
    
    # Test optional packages
    python -c "
try:
    import whisper
    print('   ✅ Whisper available')
except:
    print('   ⚠️ Whisper not available')

try:
    import pyaudio
    print('   ✅ Audio available')
except:
    print('   ⚠️ Audio not available')

try:
    import pyttsx3
    print('   ✅ TTS available')
except:
    print('   ⚠️ TTS not available')
"
else
    echo "   ❌ Environment not found"
    echo "   Run: ./setup_neomind.sh"
    exit 1
fi

# Test 2: GUI
echo ""
echo "2️⃣ Testing GUI basics..."
python -c "
import tkinter as tk
root = tk.Tk()
root.title('Test')
root.geometry('200x100')
label = tk.Label(root, text='😊 Test')
label.pack()
root.after(1000, root.quit)
try:
    root.mainloop()
    print('   ✅ GUI works')
except Exception as e:
    print(f'   ❌ GUI failed: {e}')
"

# Test 3: Server connectivity
echo ""
echo "3️⃣ Testing server connection..."
if curl -s "http://localhost:5000/health" > /dev/null 2>&1; then
    echo "   ✅ Server is running at http://localhost:5000"
else
    echo "   ⚠️ Server not running (will start automatically)"
fi

echo ""
echo "🎉 Test completed!"
echo ""
echo "If all tests passed, run: ./start_neomind.sh"
EOF

chmod +x test_neomind.sh

# Create README
cat > README.md << 'EOF'
# 🧠 NeoMind - Complete AI Companion Setup

A complete emotional AI companion with knowledge graph integration, voice interaction, and beautiful GUI.

## Quick Start

1. **Complete Setup** (run once):
   ```bash
   ./setup_neomind.sh
   ```

2. **Test Everything**:
   ```bash
   ./test_neomind.sh
   ```

3. **Start NeoMind**:
   ```bash
   ./start_neomind.sh
   ```

## What You Get

### 🎨 **Beautiful Emotional GUI**
- 8 different emotions (Happy, Excited, Thinking, etc.)
- Real-time emotion changes based on conversation
- Clean, kid-friendly interface

### 🎤 **Voice Interaction**
- Speech recognition with Whisper
- Text-to-speech responses
- Push-to-talk functionality

### 🧠 **Knowledge Integration**
- Connects to your Graphiti server
- Personalized responses
- Memory of past conversations

### 💬 **Text Chat**
- Always available fallback
- Full conversation history
- Keyboard shortcuts

## Directory Structure

```
neomind/
├── gui/
│   └── neomind_gui.py       # Main GUI application
├── server/
│   └── neomind_server.py    # Sample server (replace with yours)
├── config/
│   └── .env                 # Configuration
├── logs/
│   └── neomind.log         # Application logs
├── neomind_env/            # Python virtual environment
├── start_neomind.sh        # Main launcher
├── test_neomind.sh         # Test script
└── README.md               # This file
```

## Configuration

Edit `config/.env`:
```bash
CHILD_NAME=YourChild
NEOMIND_SERVER=http://localhost:5000
WHISPER_MODEL=tiny.en
VOICE_RATE=180
VOICE_VOLUME=0.9
```

## Using Your Own Server

Replace `server/neomind_server.py` with your Graphiti knowledge graph server. Make sure it provides these endpoints:

- `GET /health` - Health check
- `POST /chat/text` - Text chat
- `POST /memories/search` - Memory search

## Features

### Available Immediately
- ✅ Text chat interface
- ✅ Emotional expressions
- ✅ Server integration
- ✅ Conversation history

### Requires Installation
- 🎤 Voice input (needs: pyaudio, webrtcvad)
- 🧠 Speech recognition (needs: whisper)
- 🗣️ Voice output (needs: pyttsx3)

## Keyboard Shortcuts

- **Enter**: Send message
- **Ctrl+L**: Start/stop listening
- **Ctrl+T**: Test server connection
- **Ctrl+Q**: Quit application

## Troubleshooting

### "Audio not available"
```bash
# Ubuntu/Debian:
sudo apt install portaudio19-dev
pip install pyaudio webrtcvad

# Test audio:
./test_neomind.sh
```

### "Server connection failed"
1. Make sure your server is running
2. Check the URL in `config/.env`
3. Test with: `curl http://localhost:5000/health`

### "GUI issues"
```bash
# Install GUI dependencies:
sudo apt install python3-tk

# Test GUI:
python -c "import tkinter; tkinter.Tk().mainloop()"
```

## Transfer to Raspberry Pi

Once working on desktop:
1. Copy the entire `neomind/` folder
2. Run `./setup_neomind.sh` on Pi
3. Adjust performance settings in `config/.env`
4. Test with `./test_neomind.sh`

## Performance Tips

- Use `tiny.en` Whisper model for speed
- Reduce GUI size if needed
- Monitor with: `htop`
- Check logs: `tail -f logs/neomind.log`

Enjoy your emotional AI companion! 🚀
EOF

echo ""
echo "🎉 Complete NeoMind setup finished!"
echo ""
echo "📁 Installation directory: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "1. Test the setup:    ./test_neomind.sh"
echo "2. Start NeoMind:     ./start_neomind.sh"
echo "3. Replace server:    Edit server/neomind_server.py with your Graphiti server"
echo "4. Customize:         Edit config/.env for your preferences"
echo ""
echo "🎯 Everything is ready to go!"
echo "📖 See README.md for detailed instructions"