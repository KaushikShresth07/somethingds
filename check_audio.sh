#!/bin/bash
# Check if audio is being captured

echo "Checking audio setup..."
echo ""

# Check PulseAudio
echo "1. PulseAudio status:"
pactl list sinks short 2>/dev/null | grep voicebot_sink && echo "   ✓ voicebot_sink exists" || echo "   ✗ voicebot_sink NOT found"

# Check if ffmpeg is recording
echo ""
echo "2. FFmpeg processes:"
ps aux | grep ffmpeg | grep -v grep && echo "   ✓ FFmpeg is running" || echo "   ✗ FFmpeg is NOT running"

# Check audio file
echo ""
echo "3. Audio files:"
if ls voice_assistant_*.wav 1> /dev/null 2>&1; then
    for file in voice_assistant_*.wav; do
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo "0")
        echo "   File: $file"
        echo "   Size: $SIZE bytes"
        if [ "$SIZE" -gt 10000 ]; then
            echo "   ✓ File has content (likely has audio)"
        else
            echo "   ⚠ File is very small (may be empty)"
        fi
    done
else
    echo "   ✗ No audio files found"
fi

echo ""
echo "4. Browser processes:"
ps aux | grep -E "(chromium|chrome|playwright)" | grep -v grep | head -3

