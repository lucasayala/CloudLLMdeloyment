#!/bin/bash

# Name of the script
SCRIPT_NAME="setup_dolphin_web_interface.sh"

# Function to check if a command is available
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a directory exists
function directory_exists() {
    if [ -d "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a file exists
function file_exists() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Update the package manager
sudo apt-get update

# Install necessary packages
sudo apt-get install -y python3 python3-pip git python3-venv

# Check if virtualenv is available
if ! command_exists virtualenv; then
    echo "Error: virtualenv command not found. Please install it first."
    exit 1
fi

# Create a new virtual environment
python3 -m venv venv
source venv/bin/activate

# Install required Python packages
pip install transformers flask flask_socketio eventlet gevent numpy torch huggingface-cli

# Download and install the Dolphin model
huggingface-cli login
huggingface-cli repo download cognitivecomputations/dolphin-2.8-mistral-7b-v02

# Create a directory for the web interface
web_interface_dir="dolphin_web_interface"

# Check if the web interface directory already exists
if directory_exists $web_interface_dir; then
    echo "Error: Directory '$web_interface_dir' already exists. Please remove it first."
    exit 1
fi

# Create the web interface directory
mkdir $web_interface_dir

# Create a Python file for the Flask app
touch $web_interface_dir/app.py

# Write the content to app.py
cat > $web_interface_dir/app.py << EOF
from flask import Flask, render_template, request, jsonify, send_file
from flask_socketio import SocketIO, emit
from transformers import AutoModelForCausalLM
import torch
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your_secret_key_here'
socketio = SocketIO(app)

# Load the Dolphin model
model_name = 'cognitivecomputations/dolphin-2.8-mistral-7b-v02'
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = AutoModelForCausalLM.from_pretrained(model_name).to(device)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/chat', methods=['POST'])
def chat():
    user_input = request.json.get('message')
    inputs = model.encode(user_input, return_tensors='pt').to(device)
    response = model.generate(inputs, max_length=100, num_return_sequences=1)
    response = response[0].tolist()[0]
    response = model.tokenizer.decode(response, skip_special_tokens=True)
    return jsonify(response)

@app.route('/upload', methods=['POST'])
def upload():
    file = request.files['file']
    if file.filename != '':
        file_path = os.path.join(app.root_path, 'uploads', file.filename)
        file.save(file_path)
        return jsonify({'message': 'File uploaded successfully'}), 201
    else:
        return jsonify({'error': 'No file selected'}), 400

@app.route('/download/<filename>')
def download(filename):
    file_path = os.path.join(app.root_path, 'uploads', filename)
    return send_file(file_path, as_attachment=True)

# ... (rest of the web interface code remains the same)
EOF

# Create a directory for HTML templates
mkdir $web_interface_dir/templates

# Check if the templates directory already exists
if directory_exists $web_interface_dir/templates; then
    echo "Error: Directory '$web_interface_dir/templates' already exists. Please remove it first."
    exit 1
fi

# Create the HTML template file
touch $web_interface_dir/templates/index.html

# Write the content to index.html
cat > $web_interface_dir/templates/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Dolphin Web Interface</title>
</head>
<body>
    <h1>Dolphin Web Interface</h1>
    <div id="chat-box"></div>
    <form id="chat-form">
        <input type="text" id="user-input" placeholder="Type your message">
        <button type="submit">Send</button>
    </form>
    <button id="learn-mode-button">Toggle Learn Mode</button>
    <input type="file" id="file-upload" accept=".npz">
    <button id="upload-button">Upload File</button>
    <a id="download-link" href="/download/example.txt" download>Download File</a>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.4.0/socket.io.js"></script>
    <script>
        var socket = io.connect('http://localhost:8080');
        var chatBox = document.getElementById('chat-box');
        var userInput = document.getElementById('user-input');
        var chatForm = document.getElementById('chat-form');
        var learnModeButton = document.getElementById('learn-mode-button');
        var fileUpload = document.getElementById('file-upload');
        var uploadButton = document.getElementById('upload-button');
        var downloadLink = document.getElementById('download-link');

        chatForm.addEventListener('submit', function(event) {
            event.preventDefault();
            var message = userInput.value;
            socket.emit('chat', { message: message });
            userInput.value = '';
        });

        socket.on('chat', function(data) {
            var message = data.message;
            var messageElement = document.createElement('p');
            messageElement.textContent = message;
            chatBox.appendChild(messageElement);
        });

        learnModeButton.addEventListener('click', function() {
            // Implement learn mode functionality here
        });

        socket.on('learn_mode_response', function(data) {
            // Implement response to learn mode toggle here
        });

        fileUpload.addEventListener('change', function() {
            var formData = new FormData();
            formData.append('file', fileUpload.files[0]);
            socket.emit('upload', formData);
        });

        uploadButton.addEventListener('click', function() {
            fileUpload.click();
        });

        downloadLink.addEventListener('click', function() {
            // Implement download functionality here
        });
    </script>
</body>
</html>
EOF

# Create a directory for uploaded files
mkdir $web_interface_dir/uploads

# Activate the virtual environment and run the Flask app
source venv/bin/activate
cd $web_interface_dir

# Display a success message and provide a link to the web interface
echo "Setup completed successfully!"
echo "You can now access the Dolphin web interface at: http://localhost:8080"

# Run the Flask app
python app.py

