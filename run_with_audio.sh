#!/bin/bash
# Helper script to run voice assistant with audio support on Linux

# Check if xvfb is installed
if ! command -v xvfb-run &> /dev/null; then
    echo "Xvfb not found. Installing..."
    sudo apt update
    sudo apt install -y xvfb pulseaudio pulseaudio-utils
fi

# Start PulseAudio if not running
if ! pgrep -x "pulseaudio" > /dev/null; then
    echo "Starting PulseAudio..."
    pulseaudio --start --system
fi

# Run with virtual display
echo "Starting voice assistant with audio support..."
xvfb-run -a python talk.py

