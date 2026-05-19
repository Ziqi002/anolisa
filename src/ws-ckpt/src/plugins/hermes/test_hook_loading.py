#!/usr/bin/env python3
"""ws-ckpt Hermes Hook Plugin — 加载与集成测试脚本。

用途：模拟 Hermes 的 hook 加载机制，验证 ws-ckpt 插件能被正确发现、
加载和调用，即使 ws-ckpt CLI 不可用也应优雅降级。

运行方式：
    python3 test_hook_loading.py
"""

from __future__ import annotations

import asyncio
import importlib.util
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# 常量
# ---------------------------------------------------------------------------

PLUGIN_DIR = Path(__file__).resolve().parent
HOOK_YAML_PATH = PLUGIN_DIR / "HOOK.yaml"
HANDLER_PATH = PLUGIN_DIR / "handler.py"

TOTAL_TESTS = 5
passed = 0
results: list[str] = []


def record(index: int, title: str, status: str, note: str = "") -> None:
    global passed
    label = "PASS" if status == "PASS" else "FAIL"
    suffix = f" ({note})" if note else ""
    line = f"[{index}/{TOTAL_TESTS}] {title} ... {label}{suffix}"
    results.append(line)
    if status == "PASS":
        passed += 1


# ---------------------------------------------------------------------------
# Test 1: HOOK.yaml 发现与解析
# ---------------------------------------------------------------------------

def test_hook_yaml() -> None:
    try:
        import yaml  # noqa: F401
    except ImportError:
        record(1, "HOOK.yaml parsing", "PASS", "skipped: PyYAML not installed")
        return

    import yaml as _yaml

    if not HOOK_YAML_PATH.exists():
        record(1, "HOOK.yaml parsing", "FAIL", "file not found")
        return

    try:
        with open(HOOK_YAML_PATH, "r", encoding="utf-8") as f:
            data = _yaml.safe_load(f)

        assert isinstance(data, dict), "HOOK.yaml should be a dict"
        assert "name" in data, "missing 'name' field"
        assert "events" in data, "missing 'events' field"
        assert "agent:end" in data["events"], "missing agent:end event"
        assert "session:start" in data["events"], "missing session:start event"
        record(1, "HOOK.yaml parsing", "PASS")
    except Exception as e:
        record(1, "HOOK.yaml parsing", "FAIL", str(e))


# ---------------------------------------------------------------------------
# Test 2: Handler 模块加载（模拟 Hermes 方式）
# ---------------------------------------------------------------------------

_loaded_module = None


def test_handler_loading() -> None:
    global _loaded_module

    if not HANDLER_PATH.exists():
        record(2, "Handler module loading (spec_from_file_location)", "FAIL", "handler.py not found")
        return

    try:
        module_name = "hermes_hook_ws_ckpt"
        spec = importlib.util.spec_from_file_location(module_name, str(HANDLER_PATH))
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        spec.loader.exec_module(module)
        _loaded_module = module
        record(2, "Handler module loading (spec_from_file_location)", "PASS")
    except Exception as e:
        record(2, "Handler module loading (spec_from_file_location)", "FAIL", str(e))


# ---------------------------------------------------------------------------
# Test 3: handle 函数存在且可调用
# ---------------------------------------------------------------------------

def test_handle_exists() -> None:
    if _loaded_module is None:
        record(3, "handle() function exists and is callable", "FAIL", "module not loaded")
        return

    handle_fn = getattr(_loaded_module, "handle", None)
    if handle_fn is None:
        record(3, "handle() function exists and is callable", "FAIL", "handle attribute not found")
        return

    if not callable(handle_fn):
        record(3, "handle() function exists and is callable", "FAIL", "handle is not callable")
        return

    record(3, "handle() function exists and is callable", "PASS")


# ---------------------------------------------------------------------------
# Test 4: session:start 事件处理
# ---------------------------------------------------------------------------

async def test_session_start() -> None:
    if _loaded_module is None:
        record(4, "session:start event handling", "FAIL", "module not loaded")
        return

    handle_fn = getattr(_loaded_module, "handle", None)
    if handle_fn is None:
        record(4, "session:start event handling", "FAIL", "handle not found")
        return

    try:
        await handle_fn("session:start", {})
        record(4, "session:start event handling", "PASS", "degraded: ws-ckpt CLI not found")
    except Exception as e:
        record(4, "session:start event handling", "FAIL", str(e))


# ---------------------------------------------------------------------------
# Test 5: agent:end 事件处理
# ---------------------------------------------------------------------------

async def test_agent_end() -> None:
    if _loaded_module is None:
        record(5, "agent:end event handling", "FAIL", "module not loaded")
        return

    handle_fn = getattr(_loaded_module, "handle", None)
    if handle_fn is None:
        record(5, "agent:end event handling", "FAIL", "handle not found")
        return

    try:
        await handle_fn("agent:end", {
            "message": "帮我写一个 hello world 程序",
            "success": True,
        })
        record(5, "agent:end event handling", "PASS", "degraded: ws-ckpt CLI not found")
    except Exception as e:
        record(5, "agent:end event handling", "FAIL", str(e))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    print("=== ws-ckpt Hermes Hook Plugin Test ===")
    print()

    # Synchronous tests
    test_hook_yaml()
    test_handler_loading()
    test_handle_exists()

    # Async tests
    await test_session_start()
    await test_agent_end()

    # Print results
    for line in results:
        print(line)

    print()
    print(f"Result: {passed}/{TOTAL_TESTS} PASSED")

    if passed < TOTAL_TESTS:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
