import os
import json
import time
import base64
import tempfile
import argparse
import pyautogui
import pyperclip
from datetime import datetime
from PIL import ImageGrab
from anthropic import Anthropic
from dotenv import load_dotenv

# ── Safety: move mouse to top-left corner to abort ──────────────────────────
pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.4   # small delay between every pyautogui call

load_dotenv()

client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
DEFAULT_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-opus-4-5")

SYSTEM_PROMPT = """\
You are a computer-use automation agent running on a {w}x{h} Windows desktop.

Your job is to complete the user's goal by choosing ONE action at a time.
After each action you will receive a fresh screenshot so you can see the result.

Reply with ONLY a single JSON object — no explanation, no markdown fences.

Allowed actions:
  {{"type": "screenshot"}}                              — take a screenshot to look at the screen
  {{"type": "left_click",   "coordinate": [x, y]}}     — single left click
  {{"type": "double_click", "coordinate": [x, y]}}     — double click
  {{"type": "right_click",  "coordinate": [x, y]}}     — right click
  {{"type": "move",         "coordinate": [x, y]}}     — move mouse without clicking
  {{"type": "type",         "text": "..."}}             — type text (keyboard)
  {{"type": "key",          "key":  "..."}}             — press a key e.g. "enter","ctrl+s","alt+f4"
  {{"type": "scroll",       "coordinate": [x, y], "direction": "up"}}   — scroll up
  {{"type": "scroll",       "coordinate": [x, y], "direction": "down"}} — scroll down
  {{"type": "done"}}                                   — goal is complete

Rules:
- Think step-by-step but only output the JSON for the NEXT action.
- Use coordinates that refer to pixels on the screen (origin top-left).
- When you finish the goal reply with {{"type": "done"}}.
"""


def grab_screenshot(tmp_path: str) -> str:
    """Capture the full screen and return as base64-encoded PNG."""
    img = ImageGrab.grab()
    img.save(tmp_path)
    with open(tmp_path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8")


def execute_action(action: dict, tmp_path: str) -> str | None:
    """Execute an action dict and return base64 screenshot (for 'screenshot' type)."""
    atype = action.get("type", "")
    coord = action.get("coordinate", [0, 0])
    x, y = coord[0], coord[1]

    if atype == "screenshot":
        return grab_screenshot(tmp_path)
    elif atype == "left_click":
        pyautogui.click(x, y)
    elif atype == "double_click":
        pyautogui.doubleClick(x, y)
    elif atype == "right_click":
        pyautogui.rightClick(x, y)
    elif atype == "move":
        pyautogui.moveTo(x, y)
    elif atype == "type":
        # Use clipboard paste to correctly handle unicode and special characters
        pyperclip.copy(action.get("text", ""))
        pyautogui.hotkey("ctrl", "v")
    elif atype == "key":
        keys = action.get("key", "").split("+")
        pyautogui.hotkey(*keys)
    elif atype == "scroll":
        direction = action.get("direction", "down")
        clicks = -5 if direction == "down" else 5
        pyautogui.scroll(clicks, x=x, y=y)
    elif atype == "done":
        pass
    else:
        print(f"[WARN] Unknown action type: {atype}")
    return None


def parse_json(raw: str) -> dict | None:
    """Extract JSON from the model response (handles accidental markdown fences)."""
    raw = raw.strip()

    # Strip ```json ... ``` or ``` ... ``` if the model wraps it anyway
    if raw.startswith("```"):
        lines = raw.split("\n")
        raw = "\n".join(lines[1:-1]) if len(lines) > 2 else raw

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        # Last attempt: find first { ... }
        start = raw.find("{")
        end = raw.rfind("}")
        if start != -1 and end != -1:
            try:
                return json.loads(raw[start : end + 1])
            except json.JSONDecodeError:
                pass
    return None


def run(goal: str, max_steps: int = 30, model: str = DEFAULT_MODEL, skip_confirm: bool = False):
    w, h = pyautogui.size()
    system = SYSTEM_PROMPT.format(w=w, h=h)

    print(f"\n{'='*60}")
    print(f"  GOAL: {goal}")
    print(f"  Screen: {w}x{h}  |  Max steps: {max_steps}  |  Model: {model}")
    print(f"  SAFETY: Move mouse to top-left corner to abort!")
    print(f"{'='*60}")

    if not skip_confirm:
        confirm = input("\nStart? [y/N]: ").strip().lower()
        if confirm != "y":
            print("Aborted.")
            return

    # Set up session log
    os.makedirs("logs", exist_ok=True)
    log_path = os.path.join("logs", datetime.now().strftime("session_%Y%m%d_%H%M%S.log"))
    log_file = open(log_path, "w", encoding="utf-8")
    log_file.write(f"Goal: {goal}\nModel: {model}\nMax steps: {max_steps}\n\n")

    time.sleep(1.5)  # small pause so user can read

    # Temp file for screenshots (cleaned up in finally block)
    tmp_fd, tmp_path = tempfile.mkstemp(suffix=".png")
    os.close(tmp_fd)

    messages = []

    try:
        for step in range(1, max_steps + 1):
            print(f"\n[Step {step}/{max_steps}] Capturing screen...")
            screen_b64 = grab_screenshot(tmp_path)

            # Build message with the latest screenshot
            messages.append({
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/png",
                            "data": screen_b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": (
                            f"Goal: {goal}\n"
                            "This is the current screenshot. What is the next single action?"
                        ),
                    },
                ],
            })

            response = client.messages.create(
                model=model,
                max_tokens=256,
                system=system,
                messages=messages,
            )

            raw = response.content[0].text
            print(f"[AI]   {raw.strip()}")
            log_file.write(f"[Step {step}] {raw.strip()}\n")
            log_file.flush()

            action = parse_json(raw)
            if action is None:
                print("[WARN] Could not parse AI response, skipping step.")
                messages.append({"role": "assistant", "content": raw})
                continue

            # Store assistant turn for conversation history
            messages.append({"role": "assistant", "content": raw})

            if action.get("type") == "done":
                print("\n✓ Goal completed!\n")
                log_file.write("\n✓ Goal completed!\n")
                return

            # Execute and wait for the UI to respond
            result = execute_action(action, tmp_path)
            time.sleep(0.8)

            # If the AI requested a screenshot action, inject result immediately
            if result:
                messages.append({
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/png",
                                "data": result,
                            },
                        },
                        {"type": "text", "text": "Here is the screenshot you requested."},
                    ],
                })

        print("\n[INFO] Reached max steps without completing the goal.")
        log_file.write("\n[INFO] Reached max steps without completing the goal.\n")
    finally:
        log_file.close()
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        print(f"[LOG] Session saved to {log_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AI Desktop Automation Agent")
    parser.add_argument("goal", nargs="?", help="Goal for the agent to accomplish")
    parser.add_argument("--steps", type=int, default=30, help="Max steps (default: 30)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Claude model (default: {DEFAULT_MODEL})")
    parser.add_argument("--yes", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args()

    print("=" * 60)
    print("   Computer Use — AI Desktop Automation")
    print("=" * 60)
    goal = args.goal or input("\nEnter goal (e.g. 'Open Notepad and type Hello World'): ").strip()
    if goal:
        run(goal, max_steps=args.steps, model=args.model, skip_confirm=args.yes)
    else:
        print("No goal entered. Exiting.")
