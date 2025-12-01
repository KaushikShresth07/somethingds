#!/bin/bash
# Check status of voice assistant

echo "Voice Assistant Status"
echo "======================"
echo ""

# Check Python process
if pgrep -f "python talk.py" > /dev/null; then
    echo "✓ Voice assistant is running (PID: $(pgrep -f 'python talk.py'))"
else
    echo "✗ Voice assistant is NOT running"
fi

# Check ffmpeg
if pgrep ffmpeg > /dev/null; then
    echo "✓ Audio recording is active (PID: $(pgrep ffmpeg))"
else
    echo "✗ Audio recording is NOT active"
fi

# Check Xvfb
if pgrep Xvfb > /dev/null; then
    echo "✓ Virtual display is running (PID: $(pgrep Xvfb))"
else
    echo "✗ Virtual display is NOT running"
fi

# Check PulseAudio
if pgrep pulseaudio > /dev/null; then
    echo "✓ PulseAudio is running"
else
    echo "✗ PulseAudio is NOT running"
fi

# Check audio files
echo ""
echo "Audio files:"
if ls voice_assistant_*.wav 1> /dev/null 2>&1; then
    for file in voice_assistant_*.wav; do
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo "0")
        MODIFIED=$(stat -c%y "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "  $file"
        echo "    Size: $SIZE bytes"
        echo "    Modified: $MODIFIED"
        if [ "$SIZE" -gt 10000 ]; then
            echo "    Status: ✓ Has content"
        else
            echo "    Status: ⚠ Very small (may be empty)"
        fi
    done
else
    echo "  No audio files found"
fi

# Check log files
echo ""
echo "Log files:"
if ls voicebot_*.log 1> /dev/null 2>&1; then
    LATEST_LOG=$(ls -t voicebot_*.log | head -1)
    echo "  Latest: $LATEST_LOG"
    echo "  Last 5 lines:"
    tail -5 "$LATEST_LOG" | sed 's/^/    /'
else
    echo "  No log files found"
fi

