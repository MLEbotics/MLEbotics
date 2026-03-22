# Computer Use Agent

An AI agent that controls a Windows desktop autonomously — powered by the Anthropic Claude API.

Give it a plain-English goal and it takes over: capturing screenshots, moving the mouse, typing, clicking, and scrolling until the task is done.

## How It Works

1. You describe a goal in natural language
2. The agent takes a screenshot and sends it to Claude (claude-opus-4-5 by default)
3. Claude responds with a single JSON action (click, type, scroll, key press, etc.)
4. The agent executes the action via PyAutoGUI
5. Repeat until Claude returns `{"type": "done"}`

## Features

- Full desktop control — mouse, keyboard, scroll
- Screenshot-based vision loop (no screen recording)
- Clipboard-safe text input (handles unicode correctly)
- Failsafe: move mouse to top-left corner to abort instantly
- Configurable model via `.env`

## Setup

### 1. Clone the repo
```bash
git clone https://github.com/eddie7ch/Computer-Use.git
cd Computer-Use
```

### 2. Create a virtual environment
```bash
python -m venv .venv
.venv\Scripts\activate
```

### 3. Install dependencies
```bash
pip install -r requirements.txt
```

### 4. Configure environment
Copy `.env.example` to `.env` and add your Anthropic API key:

```
ANTHROPIC_API_KEY=your_key_here
ANTHROPIC_MODEL=claude-opus-4-5
```

### 5. Run
```bash
python main.py "open Notepad and type Hello World"
```

Or use the provided launcher:
```bat
.\run.bat
```

## Requirements

- Windows 10/11
- Python 3.10+
- Anthropic API key
- A running desktop (not headless)

## Safety

- `pyautogui.FAILSAFE = True` — move mouse to the **top-left corner** of the screen at any time to immediately abort
- Always supervise the agent during execution

## Stack

| Component | Technology |
|---|---|
| AI | Anthropic Claude API |
| Desktop control | PyAutoGUI |
| Screen capture | Pillow (ImageGrab) |
| Clipboard | Pyperclip |