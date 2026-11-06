#!/usr/bin/env python3
"""DevEco Code (deveco) 的 ACP stdio 客户端 —— 供本仓库编排使用。

参考：docs/harmony/ACP_INTEGRATION.md（源自 baoagent-ohos 的 ACP 接入指南）。

用法：
    python3 tools/acp/deveco_acp.py --cwd harmonyApp "任务描述"
    python3 tools/acp/deveco_acp.py --cwd harmonyApp --prompt-file /tmp/task.md --timeout 900
    python3 tools/acp/deveco_acp.py --cwd harmonyApp --transcript /tmp/acp.log "..."

退出码：0 正常结束；2 握手失败；3 建会话失败；4 超时；5 会话出错。
"""
import argparse
import json
import os
import queue
import subprocess
import sys
import threading
import time
from typing import Optional


class AcpClient:
    def __init__(self, cwd: str, auto_approve: bool, transcript_path: Optional[str], log_level: str):
        self.cwd = cwd
        self.auto_approve = auto_approve
        self.transcript = open(transcript_path, "a", encoding="utf-8") if transcript_path else None
        self.messages: list[str] = []
        self.next_id = 0
        self.proc = subprocess.Popen(
            ["deveco", "acp", "--print-logs", "--log-level", log_level],
            cwd=cwd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.lines: queue.Queue = queue.Queue()
        threading.Thread(target=self._reader, args=(self.proc.stdout, "OUT"), daemon=True).start()
        threading.Thread(target=self._reader, args=(self.proc.stderr, "ERR"), daemon=True).start()

    def _reader(self, stream, tag: str) -> None:
        for line in stream:
            self.lines.put((tag, line.rstrip("\n")))

    def _record(self, text: str) -> None:
        self.messages.append(text)
        if self.transcript:
            self.transcript.write(text + "\n")
            self.transcript.flush()

    def send(self, method: str, params=None) -> int:
        self.next_id += 1
        msg = {"jsonrpc": "2.0", "id": self.next_id, "method": method}
        if params is not None:
            msg["params"] = params
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()
        return self.next_id

    def reply(self, msg_id, result) -> None:
        self.proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": msg_id, "result": result}) + "\n")
        self.proc.stdin.flush()

    def _handle_permission(self, msg) -> None:
        params = msg.get("params", {})
        options = params.get("options", [])
        chosen = None
        if self.auto_approve:
            for opt in options:
                if opt.get("kind") in ("allow_once", "allow_always", "allow"):
                    chosen = opt
                    break
            if chosen is None and options:
                chosen = options[0]
        if chosen is None:
            self.reply(msg["id"], {"outcome": {"outcome": "cancelled"}})
            print("[acp] permission denied (auto-approve off)", flush=True)
            return
        self.reply(msg["id"], {"outcome": {"outcome": "selected", "optionId": chosen.get("optionId")}})
        print(f"[acp] permission granted: {chosen.get('optionId')}", flush=True)

    def wait(self, msg_id: int, deadline: float, on_update=None):
        while time.time() < deadline:
            try:
                tag, line = self.lines.get(timeout=1.0)
            except queue.Empty:
                continue
            if not line.strip():
                continue
            if tag == "ERR":
                self._record(f"[stderr] {line}")
                continue
            self._record(line)
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            method = msg.get("method")
            if method == "session/request_permission":
                self._handle_permission(msg)
                continue
            if method == "session/update" and on_update is not None:
                on_update(msg.get("params", {}).get("update", {}))
            if msg.get("id") == msg_id and ("result" in msg or "error" in msg):
                return msg
        return None

    def close(self) -> None:
        try:
            self.proc.kill()
        except Exception:
            pass
        if self.transcript:
            self.transcript.close()


def printer(update: dict) -> None:
    kind = update.get("sessionUpdate")
    content = update.get("content")
    text = content.get("text") if isinstance(content, dict) else None
    if kind == "agent_message_chunk" and text:
        sys.stdout.write(text)
        sys.stdout.flush()
    elif kind == "agent_thought_chunk":
        pass
    elif kind == "tool_call":
        title = update.get("title") or update.get("toolName") or update.get("kind") or ""
        print(f"\n[acp] tool: {title}", flush=True)
    elif kind == "tool_call_update":
        status = update.get("status") or ""
        title = update.get("title") or ""
        if title or status:
            print(f"\n[acp] tool({status}): {title}", flush=True)
    elif kind == "plan":
        entries = update.get("entries") or []
        print(f"\n[acp] plan: {len(entries)} steps", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("prompt", nargs="?", help="任务描述")
    parser.add_argument("--prompt-file")
    parser.add_argument("--cwd", default=os.getcwd())
    parser.add_argument("--timeout", type=float, default=900.0)
    parser.add_argument("--auto-approve", action="store_true", default=True)
    parser.add_argument("--no-auto-approve", dest="auto_approve", action="store_false")
    parser.add_argument("--transcript")
    parser.add_argument("--log-level", default="WARN")
    parser.add_argument("--attempts", type=int, default=2)
    args = parser.parse_args()

    text = args.prompt or ""
    if args.prompt_file:
        with open(args.prompt_file, encoding="utf-8") as f:
            text = f.read()
    if not text.strip():
        parser.error("需要 prompt 或 --prompt-file")

    text_ready = text

    def run_once() -> int:
        client = AcpClient(args.cwd, args.auto_approve, args.transcript, args.log_level)
        try:
            rid = client.send(
                "initialize",
                {"protocolVersion": 1, "clientCapabilities": {"fs": {"readTextFile": False, "writeTextFile": False}}},
            )
            if client.wait(rid, time.time() + 90) is None:
                print("[acp] initialize 无响应", flush=True)
                return 2

            rid = client.send("session/new", {"cwd": args.cwd, "mcpServers": []})
            init = client.wait(rid, time.time() + 90)
            if init is None or "result" not in init:
                print(f"[acp] session/new 失败: {init}", flush=True)
                return 3
            session_id = init["result"].get("sessionId")
            print(f"[acp] session={session_id}", flush=True)

            rid = client.send("session/prompt", {"sessionId": session_id, "prompt": [{"type": "text", "text": text_ready}]})
            result = client.wait(rid, time.time() + args.timeout, on_update=printer)
            print("", flush=True)
            if result is None:
                print(f"[acp] 超时（{args.timeout}s）", flush=True)
                return 4
            if "error" in result:
                print(f"[acp] 会话错误: {result['error']}", flush=True)
                return 5
            stop = result.get("result", {}).get("stopReason")
            print(f"[acp] stopReason={stop}", flush=True)
            return 0
        finally:
            client.close()

    last = 1
    for attempt in range(1, args.attempts + 1):
        print(f"[acp] attempt {attempt}/{args.attempts}", flush=True)
        last = run_once()
        if last in (0, 4, 5):
            return last
        time.sleep(2)
    return last


if __name__ == "__main__":
    sys.exit(main())
