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
