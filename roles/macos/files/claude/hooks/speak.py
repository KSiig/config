#!/usr/bin/env python3
"""Claude Code Stop hook: speak the last assistant message via a local mlx-audio server.

Falls back to macOS `say` where that server cannot run (Intel Macs) or the
voice sample is missing.
"""
import array
import json
import os
import platform
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request

SERVER_URL = "http://127.0.0.1:8000/v1/audio/speech"
MODEL = "mlx-community/OmniVoice-bf16"
# Voice is cloned from this clip; the transcript must match what it says.
# OmniVoice uses at most 10 s of reference, so the clip ends on a sentence.
REF_AUDIO = os.path.expanduser("~/voices/linus-2-ref.wav")
REF_TEXT = (
    "The helper works, so PSQL against dev is now one command away. "
    "But the result confirms the limit I was worried about."
)
# Long single generations drift; speak in sentence-sized chunks instead.
# OmniVoice can't stream, so each chunk is generated in full: ~1 s per request
# plus ~0.15x real time. The first chunk is short so speech starts soon; ffplay
# buffers each chunk, so the next one generates while the current one plays.
FIRST_CHUNK_CHARS = 100
CHUNK_CHARS = 250
# The server returns raw 16-bit mono PCM at the model's sample rate.
SAMPLE_RATE = "24000"
# atempo changes tempo but keeps the pitch.
PLAYBACK_RATE = "1.375"
MUTE_FILE = os.path.expanduser("~/.claude/.mute")
VOICE_DIR = os.path.expanduser("~/.claude/voice")
# One line per chunk (text length, audio length, error), to diagnose cut-offs.
LOG_FILE = os.path.join(VOICE_DIR, "speak.log")
# Hammerspoon runs this with a minimal PATH that lacks Homebrew and MacPorts.
FFPLAY = shutil.which("ffplay") or next(
    (p for p in ("/opt/homebrew/bin/ffplay", "/opt/local/bin/ffplay") if os.path.exists(p)), "ffplay"
)
# MLX only runs on Apple silicon; elsewhere, or without the voice sample, use `say`.
USE_SAY = platform.machine() != "arm64" or not os.path.exists(REF_AUDIO)


def clean(text: str) -> str:
    text = re.sub(r"```.*?```", " I've written the code in the terminal. ", text, flags=re.DOTALL)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = text.replace("`", "")
    text = re.sub(r"^\s*#+\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"[*_>#]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    session_id = data.get("session_id") or ""
    if not session_id:
        return 0
    last = os.path.join(VOICE_DIR, "last", session_id)
    if "--repeat" in sys.argv and data.get("text"):
        # "repeat <text>" (voice.py) reads out just that text.
        message = data["text"]
    elif "--repeat" in sys.argv:
        try:
            with open(last) as f:
                message = f.read()
        except FileNotFoundError:
            return 0
    else:
        message = data.get("last_assistant_message") or ""
        if not message.strip():
            return 0
        # Saved even while voice is off, so "repeat" can still read it.
        os.makedirs(os.path.dirname(last), exist_ok=True)
        with open(last, "w") as f:
            f.write(message)
        # Voice is off unless this session was switched on (see voice.py).
        flag = os.path.join(VOICE_DIR, session_id)
        if not os.path.isfile(flag) or os.path.exists(MUTE_FILE):
            return 0
        os.utime(flag)
    text = clean(message)
    if not text:
        return 0

    if USE_SAY:
        return speak_with_say(session_id, text)

    # One player for the whole message, so chunk boundaries don't restart
    # playback. ffplay only reads about a second ahead, so writing to it blocks
    # for most of a chunk's playback; a separate thread generates the chunks
    # ahead of it, and the next chunk is ready when the current one ends.
    player = subprocess.Popen(
        [
            FFPLAY, "-nodisp", "-autoexit", "-loglevel", "quiet",
            "-fflags", "nobuffer", "-probesize", "32", "-analyzeduration", "0",
            "-f", "s16le", "-ar", SAMPLE_RATE, "-ch_layout", "mono",
            "-af", f"atempo={PLAYBACK_RATE}", "-i", "-",
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    # Lets "voice off" stop this session mid-sentence.
    playing = os.path.join(VOICE_DIR, "playing", session_id)
    os.makedirs(os.path.dirname(playing), exist_ok=True)
    with open(playing, "w") as f:
        f.write(str(player.pid))
    audio: queue.Queue[bytes | None] = queue.Queue()

    def generate() -> None:
        try:
            for i, chunk in enumerate(chunks(text)):
                pcm = synthesize(chunk)
                log(session_id, f"chunk {i}: {len(chunk)} chars, {len(pcm) / 2 / int(SAMPLE_RATE):.1f}s audio")
                audio.put(pcm)
        except Exception as e:
            log(session_id, f"stopped: {type(e).__name__}: {e}")
        finally:
            audio.put(None)

    threading.Thread(target=generate, daemon=True).start()
    rate, tempo = int(SAMPLE_RATE), float(PLAYBACK_RATE)
    started, written = time.time(), 0.0

    def write(pcm: bytes) -> None:
        nonlocal written
        player.stdin.write(pcm)
        player.stdin.flush()
        written += len(pcm) / 2 / rate

    try:
        # Bluetooth earphones drop the first moment of audio while they wake,
        # and ffplay clips the onset of speech after it has run dry. So the
        # player never runs dry: while a chunk is generating, it is fed just
        # enough silence to stay ~0.3 s ahead of playback.
        while True:
            try:
                pcm = audio.get(timeout=0.05)
            except queue.Empty:
                if written - (time.time() - started) * tempo < 0.3:
                    write(bytes(2 * rate // 10))
                continue
            if pcm is None:
                break
            write(pcm)
        # ffplay exits at end of input before atempo and the audio device have
        # played their buffers; trailing silence keeps the last words.
        player.stdin.write(bytes(2 * int(SAMPLE_RATE)))
    except BrokenPipeError:
        pass
    finally:
        try:
            player.stdin.close()
        except BrokenPipeError:
            pass
        player.wait()
        # A newer read-out in this session may have replaced the file; leave
        # it, or "hush" could no longer stop that one.
        try:
            with open(playing) as f:
                if f.read().strip() == str(player.pid):
                    os.unlink(playing)
        except FileNotFoundError:
            pass
    return 0


def speak_with_say(session_id: str, text: str) -> int:
    player = subprocess.Popen(["/usr/bin/say", "-r", "220", text])
    playing = os.path.join(VOICE_DIR, "playing", session_id)
    os.makedirs(os.path.dirname(playing), exist_ok=True)
    with open(playing, "w") as f:
        f.write(str(player.pid))
    player.wait()
    try:
        with open(playing) as f:
            if f.read().strip() == str(player.pid):
                os.unlink(playing)
    except FileNotFoundError:
        pass
    return 0


def chunks(text: str) -> list[str]:
    sentences = []
    # Run-on text (lists without full stops) breaks at clauses instead, so no
    # chunk takes long enough to generate that playback runs dry.
    for sentence in re.split(r"(?<=[.!?])\s+", text):
        if len(sentence) > CHUNK_CHARS:
            sentences += re.split(r"(?<=[,;:])\s+", sentence)
        else:
            sentences.append(sentence)
    result, current = [], ""
    for sentence in sentences:
        limit = CHUNK_CHARS if result else FIRST_CHUNK_CHARS
        if current and len(current) + len(sentence) + 1 > limit:
            result.append(current)
            current = sentence
        else:
            current = f"{current} {sentence}".strip()
    if current:
        result.append(current)
    return result


def synthesize(text: str) -> bytes:
    body = json.dumps({
        "model": MODEL, "input": text, "ref_audio": REF_AUDIO, "ref_text": REF_TEXT, "response_format": "pcm", "lang_code": "en",
    }).encode()
    req = urllib.request.Request(SERVER_URL, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        pcm = resp.read()
    # Drop an odd trailing byte so samples never split across chunks.
    samples = array.array("h", pcm[: len(pcm) - len(pcm) % 2])
    # Speech starts at full volume on the first sample, which clicks; fade in
    # over 20 ms after a short pause.
    fade = min(len(samples), int(SAMPLE_RATE) // 50)
    for i in range(fade):
        samples[i] = samples[i] * i // fade
    return bytes(2 * int(SAMPLE_RATE) // 10) + samples.tobytes()


def log(session_id: str, line: str) -> None:
    with open(LOG_FILE, "a") as f:
        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {session_id[:8]} {line}\n")


if __name__ == "__main__":
    sys.exit(main())
