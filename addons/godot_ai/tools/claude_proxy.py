#!/usr/bin/env python3
"""
claude_proxy.py — OpenAI-compatible HTTP proxy for the Claude Code CLI.

Routes /v1/chat/completions requests through the local `claude` CLI so that
GodotAI (and other OpenAI-compatible clients) can use a Claude Pro/Max
subscription without needing a separate Anthropic API key.

Usage:
    python3 tools/claude_proxy.py [--port 8082] [--host 0.0.0.0] [--verbose]

Then in GodotAI Settings → Local tab, select "Claude Proxy" preset.
"""

import argparse
import errno
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

# ---------------------------------------------------------------------------
# Available models (static list returned by GET /v1/models)
# ---------------------------------------------------------------------------
CLAUDE_MODELS = [
    "sonnet",
    "opus",
    "haiku",
]

# Seconds to wait for one CLI response (long answers with code can take a while).
CLAUDE_TIMEOUT = 300

VERBOSE = False

# Resolved once at startup; on Windows this finds claude.exe / claude.cmd.
CLAUDE_PATH = shutil.which("claude") or "claude"

# Hide the console window the CLI would otherwise flash on Windows.
_CREATION_FLAGS = getattr(subprocess, "CREATE_NO_WINDOW", 0) if os.name == "nt" else 0


def log(msg: str) -> None:
    if VERBOSE:
        print(msg, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Message formatting
# ---------------------------------------------------------------------------

def format_messages(messages: list) -> tuple[str, str]:
    """
    Flatten an OpenAI messages array into (system_prompt, conversation_prompt).

    System messages are joined and passed via --system-prompt.
    User/assistant turns are formatted as Human:/Assistant: pairs so Claude
    understands the conversation history.
    """
    system_parts = []
    conversation_parts = []

    for msg in messages:
        role = msg.get("role", "")
        content = msg.get("content", "")
        if isinstance(content, list):
            # Handle content arrays (e.g. image + text) — extract text parts only
            content = " ".join(
                part.get("text", "") for part in content if part.get("type") == "text"
            )
        if role == "system":
            system_parts.append(content)
        elif role == "user":
            conversation_parts.append(f"Human: {content}")
        elif role == "assistant":
            conversation_parts.append(f"Assistant: {content}")

    system_prompt = "\n".join(system_parts)
    prompt = "\n\n".join(conversation_parts)
    return system_prompt, prompt


# ---------------------------------------------------------------------------
# OpenAI SSE chunk helpers
# ---------------------------------------------------------------------------

def make_chunk(text: str, model: str, chunk_id: str, finish_reason=None) -> str:
    """Serialise one OpenAI-format SSE data line."""
    payload = {
        "id": chunk_id,
        "object": "chat.completion.chunk",
        "created": int(time.time()),
        "model": model,
        "choices": [
            {
                "index": 0,
                "delta": {"content": text} if text else {},
                "finish_reason": finish_reason,
            }
        ],
    }
    return f"data: {json.dumps(payload)}\n\n"


def make_error_response(code: int, message: str) -> bytes:
    body = json.dumps({"error": {"message": message, "type": "server_error"}})
    return body.encode()


# ---------------------------------------------------------------------------
# Claude CLI invocation
# ---------------------------------------------------------------------------

def call_claude(prompt: str, system_prompt: str, model: str) -> str:
    """
    Run `claude --print --output-format json` and return the response text.

    The conversation is passed on stdin and the system prompt through a temp
    file, so long prompts (active script + scene tree) never hit the Windows
    32K command-line limit. Tools are disabled: this is a plain chat backend.
    Raises RuntimeError on failure.
    """
    cmd = [
        CLAUDE_PATH,
        "--print",
        "--output-format", "json",
        "--model", model,
        "--tools", "",
        "--no-session-persistence",
    ]

    sp_file = None
    if system_prompt:
        fd, sp_file = tempfile.mkstemp(prefix="godot_ai_sp_", suffix=".txt")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(system_prompt)
        cmd += ["--system-prompt-file", sp_file]

    log(f"[claude] running: {CLAUDE_PATH} --print --model {model} (prompt {len(prompt)} chars)")
    try:
        result = subprocess.run(
            cmd,
            input=prompt,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=CLAUDE_TIMEOUT,
            cwd=tempfile.gettempdir(),
            creationflags=_CREATION_FLAGS,
        )
    except FileNotFoundError:
        raise RuntimeError("'claude' command not found. Install Claude Code: https://claude.ai/code")
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Claude CLI timed out after {CLAUDE_TIMEOUT} seconds.")
    finally:
        if sp_file:
            try:
                os.remove(sp_file)
            except OSError:
                pass

    raw = (result.stdout or "").strip()
    log(f"[claude] exit={result.returncode} raw output: {raw[:200]}...")

    data = None
    try:
        data = json.loads(raw) if raw else None
    except json.JSONDecodeError:
        data = None

    if isinstance(data, dict):
        if data.get("is_error") or result.returncode != 0:
            raise RuntimeError(str(data.get("result") or result.stderr.strip() or "Unknown error from Claude CLI"))
        return data.get("result", "")

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or raw or f"claude exited with code {result.returncode}")

    # Plain text fallback (shouldn't happen with --output-format json)
    return raw


# ---------------------------------------------------------------------------
# HTTP request handler
# ---------------------------------------------------------------------------

class ProxyHandler(BaseHTTPRequestHandler):
    """Handles GET /v1/models and POST /v1/chat/completions."""

    def log_message(self, fmt, *args):  # noqa: N802
        if VERBOSE:
            super().log_message(fmt, *args)

    # ------------------------------------------------------------------
    # Routing
    # ------------------------------------------------------------------

    def do_GET(self):  # noqa: N802
        if self.path == "/v1/models":
            self._handle_models()
        else:
            self._send_json(404, {"error": {"message": f"Unknown path: {self.path}"}})

    def do_POST(self):  # noqa: N802
        if self.path == "/v1/chat/completions":
            self._handle_chat_completions()
        else:
            self._send_json(404, {"error": {"message": f"Unknown path: {self.path}"}})

    # ------------------------------------------------------------------
    # GET /v1/models
    # ------------------------------------------------------------------

    def _handle_models(self):
        body = {
            "object": "list",
            "data": [
                {"id": m, "object": "model", "owned_by": "anthropic"}
                for m in CLAUDE_MODELS
            ],
        }
        self._send_json(200, body)

    # ------------------------------------------------------------------
    # POST /v1/chat/completions
    # ------------------------------------------------------------------

    def _handle_chat_completions(self):
        length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(length)
        try:
            body = json.loads(raw_body)
        except json.JSONDecodeError:
            self._send_error(400, "Invalid JSON body")
            return

        messages = body.get("messages", [])
        model = str(body.get("model") or "sonnet").strip() or "sonnet"
        stream = body.get("stream", True)

        if not messages:
            self._send_error(400, "No messages provided")
            return

        system_prompt, prompt = format_messages(messages)
        log(f"[request] model={model} stream={stream} prompt_len={len(prompt)}")

        # Tell Python's HTTP server not to attempt another keep-alive request
        # after this response — the streaming response closes the connection.
        self.close_connection = True

        try:
            response_text = call_claude(prompt, system_prompt, model)
        except RuntimeError as err:
            self._send_error(502, str(err))
            return

        log(f"[response] text_len={len(response_text)}")

        if stream:
            self._stream_response(response_text, model)
        else:
            self._json_response(response_text, model)

    # ------------------------------------------------------------------
    # Response writers
    # ------------------------------------------------------------------

    def _stream_response(self, text: str, model: str):
        """Emit text as OpenAI SSE chunks.

        The proxy buffers the complete SSE body before sending so that a
        Content-Length header can be included.  Without it, Godot's HTTPClient
        skips STATUS_BODY entirely (no body framing → no readable chunks).
        """
        chunk_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"

        # Split into words, preserving surrounding whitespace
        words = []
        current = ""
        for ch in text:
            current += ch
            if ch in (" ", "\n", "\t"):
                words.append(current)
                current = ""
        if current:
            words.append(current)

        parts = [make_chunk(w, model, chunk_id).encode() for w in words]
        parts.append(make_chunk("", model, chunk_id, finish_reason="stop").encode())
        parts.append(b"data: [DONE]\n\n")
        body = b"".join(parts)

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        try:
            self.wfile.write(body)
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            log("[stream] client disconnected")

    def _json_response(self, text: str, model: str):
        """Return a single non-streaming OpenAI completion response."""
        body = {
            "id": f"chatcmpl-{uuid.uuid4().hex[:12]}",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": model,
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": text},
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
        }
        self._send_json(200, body)

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, code: int, message: str):
        self._send_json(code, {"error": {"message": message, "type": "server_error"}})


# ---------------------------------------------------------------------------
# Threaded server
# ---------------------------------------------------------------------------

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Handle each request in its own thread so model fetches don't block chat."""
    daemon_threads = True
    # On Windows SO_REUSEADDR lets a second server bind the same busy port,
    # which would hide the "already running" case. Keep it only elsewhere.
    allow_reuse_address = os.name != "nt"


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    global VERBOSE

    parser = argparse.ArgumentParser(
        description="OpenAI-compatible proxy for the Claude Code CLI."
    )
    parser.add_argument("--port", type=int, default=8082, help="Port to listen on (default: 8082)")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to (default: 127.0.0.1)")
    parser.add_argument("--verbose", action="store_true", help="Log requests and responses to stderr")
    args = parser.parse_args()

    VERBOSE = args.verbose

    # Verify claude CLI is available before starting
    claude_path = shutil.which("claude")
    if not claude_path:
        print(
            "ERROR: 'claude' command not found.\n"
            "Install Claude Code from https://claude.ai/code and sign in with `claude auth`.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"Claude CLI found: {claude_path}")
    print(f"Starting proxy on http://{args.host}:{args.port}")
    print("Press Ctrl+C to stop.\n")

    try:
        server = ThreadedHTTPServer((args.host, args.port), ProxyHandler)
    except OSError as err:
        if err.errno in (errno.EADDRINUSE, getattr(errno, "WSAEADDRINUSE", -1)) or getattr(err, "winerror", 0) == 10048:
            # A proxy from an earlier editor session is still serving this port.
            print(f"Port {args.port} is already in use - assuming a proxy is already running.")
            sys.exit(0)
        raise
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nProxy stopped.")


if __name__ == "__main__":
    main()
