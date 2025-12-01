#!/bin/bash
# Guaranteed audio solution - records audio directly from PulseAudio

OUTPUT_FILE="voice_assistant_$(date +%Y%m%d_%H%M%S).wav"

echo "=========================================="
echo "Voice Assistant with Audio Recording"
echo "=========================================="
echo ""
echo "This script will:"
echo "1. Set up virtual display (xvfb)"
echo "2. Configure PulseAudio"
echo "3. Start the voice assistant"
echo "4. Record audio to: $OUTPUT_FILE"
echo ""
echo "Press Ctrl+C to stop both recording and assistant"
echo "=========================================="
echo ""

# Check dependencies
if ! command -v xvfb-run &> /dev/null; then
    echo "Installing xvfb..."
    sudo apt update
    sudo apt install -y xvfb pulseaudio pulseaudio-utils ffmpeg
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Installing ffmpeg..."
    sudo apt install -y ffmpeg
fi

# Kill existing PulseAudio
pkill pulseaudio 2>/dev/null || true
sleep 2

# Start Xvfb first
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
XVFB_PID=$!
sleep 2

# Start PulseAudio with proper X11 setup
export PULSE_RUNTIME_PATH=/tmp/pulse-runtime
mkdir -p /tmp/pulse-runtime

# Start PulseAudio without X11 dependency
pulseaudio --start --exit-idle-time=-1 --system=false --disallow-exit --no-cpu-limit 2>/dev/null || true
sleep 2

# Create null sink for audio capture
pactl load-module module-null-sink sink_name=voicebot_sink 2>/dev/null || true
pactl set-default-sink voicebot_sink 2>/dev/null || true

# Verify sink exists
if ! pactl list sinks short | grep -q voicebot_sink; then
    echo "Warning: Could not create audio sink, but continuing..."
fi

# Start ffmpeg recording in background
echo "Starting audio recording..."
ffmpeg -f pulse -i voicebot_sink.monitor -acodec pcm_s16le -ar 44100 -ac 2 "$OUTPUT_FILE" > /dev/null 2>&1 &
FFMPEG_PID=$!

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Stopping..."
    kill $FFMPEG_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    pkill -f "python talk.py" 2>/dev/null || true
    pkill pulseaudio 2>/dev/null || true
    echo ""
    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
        if [ "$FILE_SIZE" -gt 1000 ]; then
            echo "✓ Audio saved to: $OUTPUT_FILE ($FILE_SIZE bytes)"
        else
            echo "⚠ Audio file is very small ($FILE_SIZE bytes) - may not have captured audio"
        fi
    else
        echo "⚠ Audio file was not created"
    fi
    exit 0
}

trap cleanup INT TERM

# Start the voice assistant
echo "Starting voice assistant..."
echo "Note: Audio is being recorded in the background"
echo ""
DISPLAY=:99 python talk.py --visible

# Cleanup if script exits
cleanup

