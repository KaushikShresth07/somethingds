# Voice Assistant Automation

Automate interaction with the AI voice assistant through a headless browser. This script uses Playwright to navigate to the voice assistant page, click the call button, and maintain the connection.

## Features

- 🎙️ Automated voice assistant connection
- 🖥️ Headless browser support (perfect for servers)
- 📊 Rich terminal output with status updates
- 🔄 Automatic connection monitoring
- 🛡️ Error handling and recovery

## Prerequisites

- Python 3.8 or higher
- pip (Python package manager)

## Installation

### 1. Clone the repository (on Ubuntu server)

```bash
git clone <your-repo-url>
cd Voicebot
```

### 2. Create a virtual environment

```bash
python3 -m venv venv
source venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Install Playwright browsers

```bash
playwright install chromium
```

## Usage

### Windows (Automatic Audio Support)

The script automatically detects Windows and uses visible mode (minimized) for audio:

```bash
python talk.py
```

The browser window will be visible but audio will work. You can minimize it manually if needed.

### Ubuntu/Linux Server (With Audio) - GUARANTEED SOLUTION

**For guaranteed audio recording on Ubuntu server, use this method:**

```bash
# Pull latest changes first
git pull

# Use the guaranteed recording script
chmod +x run_with_recording.sh
./run_with_recording.sh
```

This script will:
- ✅ Set up xvfb (virtual display)
- ✅ Configure PulseAudio
- ✅ Force visible mode (not headless) for audio support
- ✅ Automatically record audio to a WAV file
- ✅ Save audio as `voice_assistant_YYYYMMDD_HHMMSS.wav`

**After running, download the audio file:**
```bash
# From your Windows machine:
scp ubuntu@37.187.222.168:~/somethingds/voice_assistant_*.wav .
```

#### Alternative: Manual Method

```bash
# Terminal 1: Start assistant with visible mode
xvfb-run -a python talk.py --visible --record

# Terminal 2: Record audio separately
chmod +x record_audio.sh
./record_audio.sh
```

### Command-line options

- `--headless`: Force headless mode (audio may not work)
- `--visible`: Force visible mode (best for audio on Windows)
- `--no-minimize`: Don't minimize browser window (Windows only)

### Examples

```bash
# Windows: Auto-detects and uses visible mode for audio
python talk.py

# Linux: Use xvfb for audio
xvfb-run -a python talk.py

# Force headless (not recommended for audio)
python talk.py --headless

# Force visible mode
python talk.py --visible
```

## How it works

1. **Navigation**: Opens the voice assistant page
2. **Button Click**: Finds and clicks the call button using XPath or CSS selectors
3. **Connection**: Monitors connection status and waits for "connected" state
4. **Keep Alive**: Maintains the connection until interrupted (Ctrl+C)

## Server Deployment

### On Ubuntu Server via SSH

**Important Note on Audio in Headless Mode:**

Headless Chrome doesn't support audio output by default. For audio to work on a server, you have two options:

#### Option 1: Use Virtual Display (Recommended for Audio)

1. Install Xvfb (virtual display) and audio packages:
   ```bash
   sudo apt update
   sudo apt install -y xvfb pulseaudio pulseaudio-utils
   ```

2. Start PulseAudio in system mode:
   ```bash
   pulseaudio --start --system
   ```

3. Run with virtual display:
   ```bash
   xvfb-run -a python talk.py
   ```

#### Option 2: Use New Headless Mode (May have limited audio support)

The script automatically tries Playwright's new headless mode which has better audio support:
```bash
python talk.py
```

#### Option 3: Use Visible Mode with X11 Forwarding

If you need full audio support, use visible mode with X11 forwarding:
```bash
# On your local machine (before SSH)
ssh -X user@your-server-ip

# On server
python talk.py --visible
```

### Basic Setup Steps

1. SSH into your server:
   ```bash
   ssh user@your-server-ip
   ```

2. Clone and set up (as shown in Installation)

3. Run the script:
   ```bash
   # For headless (may not have audio)
   python talk.py
   
   # Or with virtual display (better audio support)
   xvfb-run -a python talk.py
   ```

4. The voice assistant will connect and remain active. Press `Ctrl+C` to disconnect.

### Running in Background

You can use `tmux` or `screen` to keep it running:

```bash
# Using tmux
tmux new -s voicebot
python talk.py
# Press Ctrl+B then D to detach

# Reattach later
tmux attach -t voicebot
```

Or use `nohup`:

```bash
nohup python talk.py > voicebot.log 2>&1 &
```

## Troubleshooting

### Browser not found

If you get an error about the browser, make sure you ran:
```bash
playwright install chromium
```

### Button not found

If the call button isn't found:
- Check if the website structure has changed
- Run with `--visible` flag to see what's happening
- Check `error_screenshot.png` if it was generated

### No Audio in Headless Mode

**Windows**: The script automatically uses visible mode (minimized) for audio support. Just run:
```bash
python talk.py
```

**Linux/Ubuntu Server**: Use xvfb for audio:
```bash
# Install dependencies (one-time)
sudo apt install xvfb pulseaudio pulseaudio-utils

# Run with audio
xvfb-run -a python talk.py

# Or use the helper script
chmod +x run_with_audio.sh
./run_with_audio.sh
```

The script auto-detects your OS and chooses the best mode for audio support.

### Connection issues

- Ensure your server has internet connectivity
- Check firewall settings
- Verify the URL is accessible
- Check browser console logs for errors

### Page closes unexpectedly

- The script now has better error handling
- Check if there are JavaScript errors on the page
- Try running with `--visible` to see what's happening
- Ensure all dependencies are installed correctly

## Development

### Testing locally

1. Run with visible browser to debug:
   ```bash
   python talk.py --visible
   ```

2. Check console output for any errors

3. Screenshots are saved automatically on errors (when in headless mode)

## License

MIT

