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
