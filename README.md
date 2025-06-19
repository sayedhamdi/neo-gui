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
