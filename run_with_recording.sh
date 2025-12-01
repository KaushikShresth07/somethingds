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
sleep 1

# Start PulseAudio
export DISPLAY=:99
export PULSE_RUNTIME_PATH=/tmp/pulse-runtime
mkdir -p /tmp/pulse-runtime

pulseaudio --start --exit-idle-time=-1 --system=false --disallow-exit
sleep 1

# Create null sink for audio capture
pactl load-module module-null-sink sink_name=voicebot_sink 2>/dev/null || true
pactl set-default-sink voicebot_sink 2>/dev/null || true

# Start ffmpeg recording in background
echo "Starting audio recording..."
ffmpeg -f pulse -i voicebot_sink.monitor -acodec pcm_s16le -ar 44100 -ac 2 "$OUTPUT_FILE" > /dev/null 2>&1 &
FFMPEG_PID=$!

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Stopping..."
    kill $FFMPEG_PID 2>/dev/null || true
    pkill -f "python talk.py" 2>/dev/null || true
    echo "Audio saved to: $OUTPUT_FILE"
    exit 0
}

trap cleanup INT TERM

# Start the voice assistant
echo "Starting voice assistant..."
DISPLAY=:99 xvfb-run -a -s "-screen 0 1920x1080x24" python talk.py --visible

# Cleanup if script exits
cleanup

