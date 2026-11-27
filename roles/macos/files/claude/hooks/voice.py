#!/usr/bin/env python3
"""Per-session voice output switch for the speak.py Stop hook.

A session speaks only while ~/.claude/voice/<session_id> exists.

  voice.py prompt          UserPromptSubmit hook: "voice on" / "voice off" / "voice" toggle it,
                           "repeat" speaks the last message again, "say <text>" speaks
                           <text>, "hush" / "shh" stop what is playing
  voice.py hotkey          Hammerspoon: toggle the session in the most recently used tmux pane
  voice.py hotkey-repeat   Hammerspoon: repeat that session's last message, or stop it if it
                           is playing
"""
import glob
import json
import os
import shutil
import signal
import subprocess
import sys
import time

VOICE_DIR = os.path.expanduser("~/.claude/voice")
PLAYING_DIR = os.path.join(VOICE_DIR, "playing")
LAST_DIR = os.path.join(VOICE_DIR, "last")
SPEAK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "speak.py")
SESSIONS_DIR = os.path.expanduser("~/.claude/sessions")
# Flags not used for this long belong to sessions that are gone.
STALE_SECONDS = 7 * 24 * 3600
COMMANDS = {
    "voice on": "on", "voice off": "off", "voice": "toggle", "repeat": "repeat",
    "hush": "stop", "shh": "stop",
}
VOICE_ON_CONTEXT = (
    "Voice is ON: your final message will be read aloud. Write it as natural speech, the way you'd say it "
    "to a colleague: flowing sentences, contractions, no bold labels, headers, tables or file paths. "
    "Keep a bold check question last if the turn has one."
)
VOICE_OFF_CONTEXT = "Voice is OFF: your final message is read as text. Normal written markdown is fine."


def flag_path(session_id: str) -> str:
    return os.path.join(VOICE_DIR, session_id)


def is_on(session_id: str) -> bool:
    return os.path.exists(flag_path(session_id))


def set_voice(session_id: str, action: str) -> bool:
    os.makedirs(PLAYING_DIR, exist_ok=True)
    prune()
    turn_on = not is_on(session_id) if action == "toggle" else action == "on"
    if turn_on:
        open(flag_path(session_id), "w").close()
    else:
        try:
            os.unlink(flag_path(session_id))
        except FileNotFoundError:
            pass
        stop_playback(session_id)
    return turn_on


def stop_playback(session_id: str) -> bool:
    """Stop this session's read-out; True if one was playing."""
    path = os.path.join(PLAYING_DIR, session_id)
    stopped = False
    try:
        with open(path) as f:
            os.kill(int(f.read().strip()), signal.SIGTERM)
        stopped = True
    except (FileNotFoundError, ValueError, ProcessLookupError):
        pass
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    return stopped


def repeat(session_id: str, text: str = "") -> bool:
    if not text and not os.path.isfile(os.path.join(LAST_DIR, session_id)):
        return False
    stop_playback(session_id)
    # Detached, so the prompt hook and Hammerspoon return straight away.
    speak = subprocess.Popen(
        [sys.executable, SPEAK, "--repeat"], stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
    )
    speak.stdin.write(json.dumps({"session_id": session_id, "text": text}).encode())
    speak.stdin.close()
    return True


def prune() -> None:
    cutoff = time.time() - STALE_SECONDS
    for path in glob.glob(os.path.join(VOICE_DIR, "*", "*")) + glob.glob(os.path.join(VOICE_DIR, "*")):
        if os.path.isfile(path) and os.path.getmtime(path) < cutoff:
            os.unlink(path)


def prompt_hook() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    prompt = data.get("prompt") or ""
    action = COMMANDS.get(" ".join(prompt.lower().split()).rstrip("."))
    session_id = data.get("session_id")
    if not session_id:
        return 0
    # "say <text>" reads out <text>, e.g. a section pasted from the last message.
    words = prompt.split(maxsplit=1)
    if not action and len(words) == 2 and words[0].lower().rstrip(":") == "say":
        repeat(session_id, words[1])
        print(json.dumps({"decision": "block", "reason": "Reading that out."}))
        return 0
    if not action:
        # Tell Claude how this turn's final message will be consumed.
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": VOICE_ON_CONTEXT if is_on(session_id) else VOICE_OFF_CONTEXT,
        }}))
        return 0
    if action == "repeat":
        reason = "Repeating the last message." if repeat(session_id) else "No message to repeat yet."
    elif action == "stop":
        reason = "Stopped." if stop_playback(session_id) else "Nothing is playing."
    else:
        reason = f"Voice {'on' if set_voice(session_id, action) else 'off'} for this session."
    # Blocking keeps the command out of the conversation, so it costs no turn.
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


def active_pane() -> "str | None":
    tmux = shutil.which("tmux") or next(
        (p for p in ("/opt/homebrew/bin/tmux", "/opt/local/bin/tmux") if os.path.exists(p)), "tmux"
    )
    out = subprocess.run(
        [tmux, "list-clients", "-F", "#{client_activity} #{pane_id}"],
        capture_output=True, text=True, check=False,
    ).stdout.split("\n")
    clients = sorted((line.split() for line in out if line.strip()), key=lambda c: int(c[0]))
    return clients[-1][1] if clients else None


def session_in_pane(pane: str) -> "dict | None":
    for path in glob.glob(os.path.join(SESSIONS_DIR, "*.json")):
        try:
            with open(path) as f:
                session = json.load(f)
            os.kill(session["pid"], 0)
        except (OSError, ValueError, KeyError):
            continue
        if (session.get("tmux") or "").endswith("." + pane):
            return session
    return None


def hotkey(action: str) -> int:
    pane = active_pane()
    session = session_in_pane(pane) if pane else None
    if not session:
        print("No Claude session in the active tmux pane")
        return 1
    name = session.get("name") or session["sessionId"][:8]
    if action == "repeat":
        # The same key stops a read-out that is already playing.
        if stop_playback(session["sessionId"]):
            print(f"Stopped: {name}")
        else:
            print(f"Repeating: {name}" if repeat(session["sessionId"]) else f"Nothing to repeat: {name}")
    else:
        print(f"Voice {'on' if set_voice(session['sessionId'], 'toggle') else 'off'}: {name}")
    return 0


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    sys.exit({"prompt": prompt_hook, "hotkey": lambda: hotkey("toggle"), "hotkey-repeat": lambda: hotkey("repeat")}.get(command, lambda: 2)())
