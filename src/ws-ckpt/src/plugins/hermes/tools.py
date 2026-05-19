"""Agent-facing tools for the ws-ckpt Hermes plugin.

Tools:
  ws_ckpt_list       — list snapshots for the workspace
  ws_ckpt_checkpoint — create a new snapshot
  ws_ckpt_rollback   — rollback to a specific snapshot
  ws_ckpt_delete     — delete a snapshot
  ws_ckpt_status     — show workspace checkpoint status
"""

from __future__ import annotations

import json
import subprocess
from typing import Any, Dict, Tuple

from .config import load_config


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _get_default_workspace() -> str:
    """Get workspace from plugin config (config.yaml > env > cwd)."""
    cfg = load_config()
    return cfg.workspace_path


def _run_ws_ckpt_cmd(cmd: list) -> Tuple[bool, str]:
    """Execute a ws-ckpt CLI command and return (success, output)."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.returncode == 0, result.stdout.strip() or result.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "Command timed out (30s)"
    except FileNotFoundError:
        return False, "ws-ckpt not found. Is it installed and in PATH?"
    except Exception as e:
        return False, str(e)


def _json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False)


def _ok(output: str) -> str:
    return _json({"success": True, "output": output})


def _err(msg: str) -> str:
    return _json({"success": False, "error": msg})


# ---------------------------------------------------------------------------
# Runtime gate
# ---------------------------------------------------------------------------


def check_ws_ckpt_available() -> bool:
    """Return True when ws-ckpt CLI is available."""
    try:
        result = subprocess.run(
            ["ws-ckpt", "--version"], capture_output=True, timeout=3
        )
        return result.returncode == 0
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Schemas (OpenAI Function Calling format)
# ---------------------------------------------------------------------------

WS_CKPT_LIST_SCHEMA: Dict[str, Any] = {
    "name": "ws_ckpt_list",
    "description": (
        "List all snapshots for the workspace. Returns snapshot IDs, "
        "timestamps, and messages. Use format='json' for structured output "
        "or 'table' for human-readable display."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "workspace": {
                "type": "string",
                "description": (
                    "Path to the workspace directory. "
                    "Optional — defaults to the configured workspace path."
                ),
            },
            "format": {
                "type": "string",
                "enum": ["json", "table"],
                "description": (
                    "Output format. 'json' (default) for structured data, "
                    "'table' for human-readable table."
                ),
            },
        },
        "additionalProperties": False,
    },
}

WS_CKPT_CHECKPOINT_SCHEMA: Dict[str, Any] = {
    "name": "ws_ckpt_checkpoint",
    "description": (
        "Create a new snapshot of the workspace. Use this to save the "
        "current state before making significant changes, so you can "
        "rollback if needed."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "id": {
                "type": "string",
                "description": (
                    "Unique identifier for the snapshot. Use a short, "
                    "descriptive name (e.g. 'pre-refactor', 'before-migration')."
                ),
            },
            "message": {
                "type": "string",
                "description": (
                    "Optional description of what this snapshot captures "
                    "(e.g. 'before adding auth module')."
                ),
            },
            "workspace": {
                "type": "string",
                "description": (
                    "Path to the workspace directory. "
                    "Optional — defaults to the configured workspace path."
                ),
            },
        },
        "required": ["id"],
        "additionalProperties": False,
    },
}

WS_CKPT_ROLLBACK_SCHEMA: Dict[str, Any] = {
    "name": "ws_ckpt_rollback",
    "description": (
        "Rollback the workspace to a previous snapshot. This restores the "
        "workspace files to the state captured in the specified snapshot. "
        "Use ws_ckpt_list first to see available snapshots."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "snapshot": {
                "type": "string",
                "description": "The snapshot ID to rollback to.",
            },
            "workspace": {
                "type": "string",
                "description": (
                    "Path to the workspace directory. "
                    "Optional — defaults to the configured workspace path."
                ),
            },
        },
        "required": ["snapshot"],
        "additionalProperties": False,
    },
}

WS_CKPT_DELETE_SCHEMA: Dict[str, Any] = {
    "name": "ws_ckpt_delete",
    "description": (
        "Delete a snapshot. Removes the specified snapshot permanently. "
        "Use ws_ckpt_list to see available snapshots before deleting."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "snapshot": {
                "type": "string",
                "description": "The snapshot ID to delete.",
            },
            "force": {
                "type": "boolean",
                "description": (
                    "Skip confirmation prompt. Defaults to true since "
                    "agent calls are non-interactive."
                ),
            },
            "workspace": {
                "type": "string",
                "description": (
                    "Path to the workspace directory. "
                    "Optional — defaults to the configured workspace path."
                ),
            },
        },
        "required": ["snapshot"],
        "additionalProperties": False,
    },
}

WS_CKPT_STATUS_SCHEMA: Dict[str, Any] = {
    "name": "ws_ckpt_status",
    "description": (
        "Show the current workspace checkpoint status including the active "
        "snapshot, total snapshot count, and disk usage information."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "workspace": {
                "type": "string",
                "description": (
                    "Path to the workspace directory. "
                    "Optional — defaults to the configured workspace path."
                ),
            },
            "format": {
                "type": "string",
                "enum": ["json", "table"],
                "description": (
                    "Output format. 'json' (default) for structured data, "
                    "'table' for human-readable display."
                ),
            },
        },
        "additionalProperties": False,
    },
}


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------


def handle_ws_ckpt_list(args: Dict[str, Any], **_kwargs) -> str:
    """Handle ws_ckpt_list tool call."""
    workspace = (args.get("workspace") or "").strip() or _get_default_workspace()
    fmt = (args.get("format") or "json").strip().lower()
    if fmt not in ("json", "table"):
        fmt = "json"

    cmd = ["ws-ckpt", "list", "-w", workspace, "--format", fmt]
    success, output = _run_ws_ckpt_cmd(cmd)
    return _ok(output) if success else _err(output)


def handle_ws_ckpt_checkpoint(args: Dict[str, Any], **_kwargs) -> str:
    """Handle ws_ckpt_checkpoint tool call."""
    snapshot_id = (args.get("id") or "").strip()
    if not snapshot_id:
        return _err("'id' is required")

    workspace = (args.get("workspace") or "").strip() or _get_default_workspace()
    message = (args.get("message") or "").strip()

    cmd = ["ws-ckpt", "checkpoint", "-w", workspace, "-i", snapshot_id]
    if message:
        cmd.extend(["-m", message])

    success, output = _run_ws_ckpt_cmd(cmd)
    return _ok(output) if success else _err(output)


def handle_ws_ckpt_rollback(args: Dict[str, Any], **_kwargs) -> str:
    """Handle ws_ckpt_rollback tool call."""
    snapshot = (args.get("snapshot") or "").strip()
    if not snapshot:
        return _err("'snapshot' is required")

    workspace = (args.get("workspace") or "").strip() or _get_default_workspace()

    cmd = ["ws-ckpt", "rollback", "-w", workspace, "-s", snapshot]
    success, output = _run_ws_ckpt_cmd(cmd)
    return _ok(output) if success else _err(output)


def handle_ws_ckpt_delete(args: Dict[str, Any], **_kwargs) -> str:
    """Handle ws_ckpt_delete tool call."""
    snapshot = (args.get("snapshot") or "").strip()
    if not snapshot:
        return _err("'snapshot' is required")

    workspace = (args.get("workspace") or "").strip() or _get_default_workspace()
    force = args.get("force", True)

    cmd = ["ws-ckpt", "delete", "-s", snapshot, "-w", workspace]
    if force:
        cmd.append("--force")

    success, output = _run_ws_ckpt_cmd(cmd)
    return _ok(output) if success else _err(output)


def handle_ws_ckpt_status(args: Dict[str, Any], **_kwargs) -> str:
    """Handle ws_ckpt_status tool call."""
    workspace = (args.get("workspace") or "").strip() or _get_default_workspace()
    fmt = (args.get("format") or "json").strip().lower()
    if fmt not in ("json", "table"):
        fmt = "json"

    cmd = ["ws-ckpt", "status", "-w", workspace, "--format", fmt]
    success, output = _run_ws_ckpt_cmd(cmd)
    return _ok(output) if success else _err(output)


# ---------------------------------------------------------------------------
# Export tuple: (name, schema, handler, emoji)
# ---------------------------------------------------------------------------

TOOLS = (
    ("ws_ckpt_list", WS_CKPT_LIST_SCHEMA, handle_ws_ckpt_list, "📋"),
    ("ws_ckpt_checkpoint", WS_CKPT_CHECKPOINT_SCHEMA, handle_ws_ckpt_checkpoint, "📸"),
    ("ws_ckpt_rollback", WS_CKPT_ROLLBACK_SCHEMA, handle_ws_ckpt_rollback, "⏪"),
    ("ws_ckpt_delete", WS_CKPT_DELETE_SCHEMA, handle_ws_ckpt_delete, "🗑"),
    ("ws_ckpt_status", WS_CKPT_STATUS_SCHEMA, handle_ws_ckpt_status, "📊"),
)
