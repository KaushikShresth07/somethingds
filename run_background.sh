#!/bin/bash
# Run voice assistant in background with audio recording (no visible browser)

OUTPUT_FILE="voice_assistant_$(date +%Y%m%d_%H%M%S).wav"
LOG_FILE="voicebot_$(date +%Y%m%d_%H%M%S).log"

echo "=========================================="
echo "Voice Assistant - Background Mode"
echo "=========================================="
echo ""
echo "Browser will run on virtual display (not visible)"
echo "Audio will be recorded to: $OUTPUT_FILE"
echo "Logs will be saved to: $LOG_FILE"
echo ""
echo "To stop: pkill -f 'python talk.py' && pkill ffmpeg"
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

# Kill existing processes
pkill -f "python talk.py" 2>/dev/null || true
pkill ffmpeg 2>/dev/null || true
pkill pulseaudio 2>/dev/null || true
sleep 2

# Start Xvfb on display :99 (virtual display, not visible in RDP)
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 -ac > /dev/null 2>&1 &
XVFB_PID=$!
sleep 2

# Start PulseAudio
export PULSE_RUNTIME_PATH=/tmp/pulse-runtime
mkdir -p /tmp/pulse-runtime

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

# Wait a moment for ffmpeg to start
sleep 1

# Start the voice assistant in background
echo "Starting voice assistant (running in background)..."
echo ""
DISPLAY=:99 python talk.py --visible > "$LOG_FILE" 2>&1 &
TALK_PID=$!

echo "✓ Voice assistant started!"
echo ""
echo "Process IDs:"
echo "  Browser: $TALK_PID"
echo "  Audio Recording: $FFMPEG_PID"
echo "  Virtual Display: $XVFB_PID"
echo ""
echo "To monitor progress:"
echo "  tail -f $LOG_FILE"
echo ""
echo "To check audio file:"
echo "  ls -lh $OUTPUT_FILE"
echo ""
echo "To stop everything:"
echo "  pkill -f 'python talk.py' && pkill ffmpeg && pkill Xvfb"
echo ""
echo "Running in background... Press Ctrl+C to exit this script (processes will continue)"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Stopping processes..."
    kill $TALK_PID 2>/dev/null || true
    kill $FFMPEG_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    pkill -f "python talk.py" 2>/dev/null || true
    pkill ffmpeg 2>/dev/null || true
    pkill Xvfb 2>/dev/null || true
    pkill pulseaudio 2>/dev/null || true
    
    echo ""
    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
        if [ "$FILE_SIZE" -gt 1000 ]; then
            echo "✓ Audio saved to: $OUTPUT_FILE ($FILE_SIZE bytes)"
        else
            echo "⚠ Audio file is very small ($FILE_SIZE bytes) - may not have captured audio"
        fi
    else
        echo "⚠ Audio file was not created"
    fi
    echo "✓ Log file: $LOG_FILE"
    exit 0
}

trap cleanup INT TERM

# Keep script running to show status
echo "Monitoring... (Press Ctrl+C to stop all processes)"
while true; do
    sleep 5
    if ! kill -0 $TALK_PID 2>/dev/null; then
        echo ""
        echo "Voice assistant process ended"
        cleanup
        break
    fi
done

