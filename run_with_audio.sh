#!/bin/bash
# Helper script to run voice assistant with audio support on Linux

# Check if xvfb is installed
if ! command -v xvfb-run &> /dev/null; then
    echo "Xvfb not found. Installing..."
    sudo apt update
    sudo apt install -y xvfb pulseaudio pulseaudio-utils
fi

# Kill any existing PulseAudio processes
pkill pulseaudio 2>/dev/null || true

# Start PulseAudio in daemon mode for the user
echo "Setting up PulseAudio..."
export DISPLAY=:99
export PULSE_RUNTIME_PATH=/tmp/pulse-runtime

# Create pulse runtime directory
mkdir -p /tmp/pulse-runtime

# Start PulseAudio with null sink (virtual audio device)
pulseaudio --start --exit-idle-time=-1 --system=false --disallow-exit

# Create a null sink for audio capture
pactl load-module module-null-sink sink_name=voicebot_sink 2>/dev/null || true

# Set the null sink as default
pactl set-default-sink voicebot_sink 2>/dev/null || true

# Create a loopback to capture audio
pactl load-module module-loopback source=voicebot_sink.monitor sink=voicebot_sink 2>/dev/null || true

echo "Starting voice assistant with audio support..."
echo ""
echo "To record audio in another terminal, run:"
echo "  parecord --file-format=wav voice_output.wav"
echo "  (or use ./record_audio.sh)"
echo ""

# Run with virtual display and visible mode for better audio support
DISPLAY=:99 xvfb-run -a -s "-screen 0 1920x1080x24" python talk.py "$@"

