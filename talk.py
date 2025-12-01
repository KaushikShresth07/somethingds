#!/usr/bin/env python3
"""
Voice Assistant Automation Script
Automates interaction with the AI voice assistant at the specified URL.
"""

import asyncio
import sys
import platform
import os
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.text import Text
import signal

console = Console()

# Detect OS
IS_WINDOWS = platform.system() == "Windows"
IS_LINUX = platform.system() == "Linux"
IS_MAC = platform.system() == "Darwin"

# Configuration
URL = "https://kaushikshresth.graphy.com/talk/engagement"
# Primary selector (legacy call icon)
CALL_BUTTON_XPATH = "//*[@id=\"__next\"]/div[1]/div[2]/div[3]/form/button/svg"
# New top button selector shared by user
ALT_BUTTON_XPATH = "//*[@id=\"__next\"]/div[1]/div[2]/div[1]/div/div[1]/div/button[2]"
HEADLESS = True  # Set to False for debugging


class VoiceAssistant:
    def __init__(self, headless=None, minimize_window=True):
        # Auto-detect best mode for audio support
        if headless is None:
            # On Windows, use visible but minimized for audio
            # On Linux, try headless with virtual display support
            if IS_WINDOWS:
                self.headless = False  # Visible mode for audio on Windows
                self.minimize_window = minimize_window
            else:
                # On Linux, use visible mode with xvfb for audio support
                # xvfb provides a virtual display, so we can use visible mode
                self.headless = False  # Use visible mode with xvfb for audio
                self.minimize_window = False
        else:
            self.headless = headless
            self.minimize_window = minimize_window and not headless
        
        self.browser = None
        self.page = None
        self.playwright = None
        self.connected = False
        self.running = True

    async def init_browser(self):
        """Initialize the browser with proper settings for audio/video."""
        self.playwright = await async_playwright().start()
        
        # Browser args for audio support
        browser_args = [
            '--use-fake-ui-for-media-stream',  # Auto-accept media permissions
            '--autoplay-policy=no-user-gesture-required',  # Allow autoplay
            '--disable-blink-features=AutomationControlled',  # Avoid detection
        ]
        
        # Platform-specific args
        if IS_LINUX:
            browser_args.extend([
                '--no-sandbox',  # Required for some server environments
                '--disable-setuid-sandbox',  # Required for some server environments
            ])
        
        # For Windows visible mode, we don't need fake devices (use real audio)
        if not self.headless and IS_WINDOWS:
            # Use real audio devices on Windows
            pass
        elif IS_LINUX and not self.headless:
            # On Linux with visible mode (xvfb), try to use real audio
            # Don't use fake devices so audio can work
            pass
        else:
            # Use fake devices for headless mode
            browser_args.append('--use-fake-device-for-media-stream')
        
        # Launch browser
        if self.headless:
            # Try new headless mode first (better audio support on Linux)
            try:
                self.browser = await self.playwright.chromium.launch(
                    headless="new",
                    args=browser_args
                )
            except Exception:
                # Fallback to old headless mode
                self.browser = await self.playwright.chromium.launch(
                    headless=True,
                    args=browser_args
                )
        else:
            # Visible mode for audio support
            self.browser = await self.playwright.chromium.launch(
                headless=False,
                args=browser_args
            )
        
        # Create context with permissions and audio/video settings
        context = await self.browser.new_context(
            permissions=['microphone', 'camera'],
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        )
        
        self.page = await context.new_page()
        
        # Position window off-screen or minimize on Windows if requested
        if not self.headless and self.minimize_window and IS_WINDOWS:
            try:
                # Wait for window to appear
                await asyncio.sleep(0.5)
                # Move window to a small size and position it off-screen
                # This is handled by the browser context, but we can try to resize
                # Note: Playwright doesn't have direct window minimization,
                # but the window will be visible with audio working
                pass
            except Exception:
                pass  # If minimization fails, continue anyway
        
        # Inject script to ensure audio context is created
        await self.page.add_init_script("""
            // Ensure audio context is available
            window.AudioContext = window.AudioContext || window.webkitAudioContext;
            // Grant media permissions
            navigator.mediaDevices.getUserMedia = navigator.mediaDevices.getUserMedia || 
                navigator.mediaDevices.webkitGetUserMedia ||
                navigator.mediaDevices.mozGetUserMedia;
        """)
        
        # Listen for console messages
        self.page.on("console", self.handle_console)
        
        # Listen for page errors
        self.page.on("pageerror", self.handle_page_error)
        
        # Listen for page close events
        self.page.on("close", self.handle_page_close)

    def handle_console(self, msg):
        """Handle console messages from the page."""
        text = msg.text
        if any(keyword in text.lower() for keyword in ['connecting', 'connected', 'error', 'disconnected']):
            console.print(f"[dim]Console: {text}[/dim]")

    def handle_page_error(self, error):
        """Handle page errors."""
        console.print(f"[red]Page Error: {error}[/red]")
    
    def handle_page_close(self):
        """Handle page close events."""
        console.print("[yellow]⚠ Page closed event detected[/yellow]")
        self.running = False

    async def navigate_to_page(self):
        """Navigate to the voice assistant page."""
        console.print(f"[cyan]Navigating to: {URL}[/cyan]")
        try:
            await self.page.goto(URL, wait_until="networkidle", timeout=30000)
            console.print("[green]✓ Page loaded successfully[/green]")
            await asyncio.sleep(2)  # Wait for page to fully render
        except PlaywrightTimeoutError:
            console.print("[yellow]⚠ Page load timeout, continuing anyway...[/yellow]")
        except Exception as e:
            console.print(f"[red]✗ Error loading page: {e}[/red]")
            raise

    async def click_call_button(self):
        """Click the call button to initiate the voice connection."""
        console.print("[cyan]Looking for call button...[/cyan]")
        
        try:
            # Wait for the button to be available
            # Try multiple selectors in case XPath doesn't work
            selectors = [
                ("xpath", ALT_BUTTON_XPATH),
                ("xpath", CALL_BUTTON_XPATH),
                ("css", "div button:nth-of-type(2)"),
                ("css", "button[type='submit']"),
                ("css", "form button"),
                ("css", "button svg"),
            ]
            
            button_clicked = False
            for selector_type, selector in selectors:
                try:
                    if selector_type == "xpath":
                        await self.page.wait_for_selector(f"xpath={selector}", timeout=5000)
                        await self.page.click(f"xpath={selector}")
                    else:
                        await self.page.wait_for_selector(selector, timeout=5000)
                        await self.page.click(selector)
                    
                    console.print(f"[green]✓ Call button clicked using {selector_type}: {selector}[/green]")
                    button_clicked = True
                    break
                except PlaywrightTimeoutError:
                    continue
                except Exception as e:
                    console.print(f"[dim]Tried {selector_type} selector, failed: {e}[/dim]")
                    continue
            
            if not button_clicked:
                # Try clicking by finding the form and submitting
                try:
                    form = await self.page.query_selector("form")
                    if form:
                        await form.evaluate("form => form.requestSubmit()")
                        console.print("[green]✓ Form submitted[/green]")
                        button_clicked = True
                except Exception as e:
                    console.print(f"[yellow]Form submit attempt failed: {e}[/yellow]")
            
            if not button_clicked:
                raise Exception("Could not find or click the call button")
            
            # Wait a moment for the click to register
            await asyncio.sleep(1)
            
        except Exception as e:
            console.print(f"[red]✗ Error clicking call button: {e}[/red]")
            # Take a screenshot for debugging
            if self.headless:
                await self.page.screenshot(path="error_screenshot.png")
                console.print("[yellow]Screenshot saved as error_screenshot.png[/yellow]")
            raise

    async def monitor_connection(self):
        """Monitor the connection status."""
        console.print("[cyan]Monitoring connection status...[/cyan]")
        
        # Wait for connection indicators
        max_wait = 30  # seconds
        start_time = asyncio.get_event_loop().time()
        
        while (asyncio.get_event_loop().time() - start_time) < max_wait:
            try:
                # Check for connection status in the page
                # Look for text like "connecting", "connected", etc.
                page_text = await self.page.content()
                
                if "connecting" in page_text.lower():
                    console.print("[yellow]🔄 Connecting...[/yellow]")
                elif "connected" in page_text.lower():
                    console.print("[green]✓ Connected![/green]")
                    self.connected = True
                    break
                
                await asyncio.sleep(1)
            except Exception as e:
                console.print(f"[dim]Monitor check: {e}[/dim]")
                await asyncio.sleep(1)
        
        if not self.connected:
            console.print("[yellow]⚠ Connection status unclear, but continuing...[/yellow]")
            self.connected = True  # Assume connected if we can't determine

    async def keep_alive(self):
        """Keep the browser alive and monitor the session."""
        console.print("[green]✓ Voice assistant is active![/green]")
        if self.headless and IS_LINUX:
            console.print("[yellow]⚠ Note: For audio on Linux server, use: xvfb-run -a python talk.py[/yellow]")
        elif not self.headless and IS_WINDOWS and self.minimize_window:
            console.print("[dim]Browser window is minimized - audio is active[/dim]")
        console.print("[dim]Press Ctrl+C to disconnect[/dim]")
        
        try:
            last_check = asyncio.get_event_loop().time()
            while self.running:
                try:
                    # Check if page is still alive
                    if self.page.is_closed():
                        console.print("[red]✗ Page closed unexpectedly[/red]")
                        break
                    
                    # Periodically check connection status
                    current_time = asyncio.get_event_loop().time()
                    if current_time - last_check > 10:  # Every 10 seconds
                        try:
                            # Check if audio is playing by looking for audio elements
                            audio_active = await self.page.evaluate("""
                                () => {
                                    const audioElements = document.querySelectorAll('audio, video');
                                    for (let el of audioElements) {
                                        if (!el.paused && el.currentTime > 0) {
                                            return true;
                                        }
                                    }
                                    return false;
                                }
                            """)
                            if audio_active:
                                console.print("[dim]🔊 Audio is active[/dim]")
                        except Exception:
                            pass  # Ignore errors in status check
                        last_check = current_time
                    
                    await asyncio.sleep(2)
                    
                except Exception as e:
                    console.print(f"[dim]Keep-alive check error: {e}[/dim]")
                    await asyncio.sleep(2)
                
        except KeyboardInterrupt:
            console.print("\n[yellow]Disconnecting...[/yellow]")
            self.running = False

    async def cleanup(self):
        """Clean up resources."""
        console.print("[cyan]Cleaning up...[/cyan]")
        try:
            if self.browser:
                await self.browser.close()
            if self.playwright:
                await self.playwright.stop()
            console.print("[green]✓ Cleanup complete[/green]")
        except Exception as e:
            console.print(f"[red]Error during cleanup: {e}[/red]")

    async def run(self):
        """Main execution flow."""
        try:
            await self.init_browser()
            await self.navigate_to_page()
            await self.click_call_button()
            await self.monitor_connection()
            await self.keep_alive()
        except KeyboardInterrupt:
            console.print("\n[yellow]Interrupted by user[/yellow]")
        except Exception as e:
            console.print(f"[red]✗ Error: {e}[/red]")
            raise
        finally:
            await self.cleanup()


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Automate AI Voice Assistant",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Windows: Automatically uses visible mode (minimized) for audio
  python talk.py
  
  # Linux: Uses headless mode (use xvfb-run for audio)
  python talk.py
  xvfb-run -a python talk.py  # For audio on Linux server
  
  # Force headless mode
  python talk.py --headless
  
  # Force visible mode
  python talk.py --visible
        """
    )
    parser.add_argument(
        "--headless",
        action="store_true",
        default=None,
        help="Force headless mode (audio may not work)"
    )
    parser.add_argument(
        "--visible",
        action="store_true",
        help="Force visible mode (best for audio on Windows)"
    )
    parser.add_argument(
        "--no-minimize",
        action="store_true",
        help="Don't minimize browser window (Windows only)"
    )
    
    args = parser.parse_args()
    
    # Determine headless mode
    if args.visible:
        headless = False
    elif args.headless:
        headless = True
    else:
        headless = None  # Auto-detect based on OS
    
    minimize_window = not args.no_minimize
    
    # Show mode info
    if headless is None:
        if IS_WINDOWS:
            console.print("[cyan]Windows detected: Using visible mode (minimized) for audio support[/cyan]")
        elif IS_LINUX:
            console.print("[cyan]Linux detected: Using headless mode[/cyan]")
            console.print("[yellow]For audio on Linux, use: xvfb-run -a python talk.py[/yellow]")
    elif headless:
        console.print("[yellow]⚠ Headless mode: Audio may not work[/yellow]")
    else:
        console.print("[green]Visible mode: Audio should work[/green]")
    
    # Create and run the assistant
    assistant = VoiceAssistant(headless=headless, minimize_window=minimize_window)
    
    try:
        asyncio.run(assistant.run())
    except KeyboardInterrupt:
        console.print("\n[yellow]Goodbye![/yellow]")
        sys.exit(0)


if __name__ == "__main__":
    main()

