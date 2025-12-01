#!/bin/bash
# Script to record audio from the voice assistant session

OUTPUT_FILE="voice_assistant_audio_$(date +%Y%m%d_%H%M%S).wav"

echo "Recording audio to: $OUTPUT_FILE"
echo "Press Ctrl+C to stop recording"

# Record from the null sink
parecord --file-format=wav --channels=2 --rate=44100 "$OUTPUT_FILE" &
RECORD_PID=$!

# Wait for interrupt
trap "kill $RECORD_PID 2>/dev/null; echo 'Recording stopped. File saved: $OUTPUT_FILE'" INT TERM

wait $RECORD_PID

