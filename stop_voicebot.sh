#!/bin/bash
# Stop all voice assistant processes

echo "Stopping voice assistant processes..."

pkill -f "python talk.py" 2>/dev/null && echo "✓ Stopped Python script" || echo "  No Python process found"
pkill ffmpeg 2>/dev/null && echo "✓ Stopped audio recording" || echo "  No ffmpeg process found"
pkill Xvfb 2>/dev/null && echo "✓ Stopped virtual display" || echo "  No Xvfb process found"
pkill pulseaudio 2>/dev/null && echo "✓ Stopped PulseAudio" || echo "  No PulseAudio process found"

echo ""
echo "All processes stopped!"

