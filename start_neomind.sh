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
