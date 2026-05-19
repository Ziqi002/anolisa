"""In-memory snapshot cache for the ws-ckpt Hermes plugin."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


@dataclass
class SnapshotInfo:
    """Information about a single snapshot."""

    snapshot: str  # Snapshot ID (daemon-assigned hash or random)
    message: str = ""  # Truncated user message
    metadata: Dict[str, Any] = field(default_factory=dict)
    created_at: str = ""  # ISO 8601 timestamp

    def __post_init__(self) -> None:
        if not self.created_at:
            self.created_at = datetime.now(timezone.utc).isoformat()


class SnapshotStore:
    """In-memory snapshot store with timeline support."""

    def __init__(self) -> None:
        self._snapshots: List[SnapshotInfo] = []

    def add(self, snapshot: SnapshotInfo) -> None:
        """Add a snapshot, replacing any with the same ID."""
        idx = next(
            (i for i, s in enumerate(self._snapshots) if s.snapshot == snapshot.snapshot),
            None,
        )
        if idx is not None:
            self._snapshots[idx] = snapshot
        else:
            self._snapshots.append(snapshot)

    def get_all(self) -> List[SnapshotInfo]:
        """Return all snapshots, newest first."""
        return sorted(
            self._snapshots,
            key=lambda s: s.created_at,
            reverse=True,
        )

    def get_last(self) -> Optional[SnapshotInfo]:
        """Return the most recent snapshot."""
        if not self._snapshots:
            return None
        return max(self._snapshots, key=lambda s: s.created_at)

    def get_timeline(self) -> List[SnapshotInfo]:
        """Return all snapshots in chronological order (oldest first) for timeline display."""
        return sorted(
            self._snapshots,
            key=lambda s: s.created_at,
        )

    def set_all(self, snapshots: List[SnapshotInfo]) -> None:
        """Replace all snapshots."""
        self._snapshots = list(snapshots)

    def remove(self, snapshot_id: str) -> bool:
        """Remove a snapshot by ID. Return True if removed."""
        before = len(self._snapshots)
        self._snapshots = [s for s in self._snapshots if s.snapshot != snapshot_id]
        return len(self._snapshots) < before

    def clear(self) -> None:
        """Clear all snapshots."""
        self._snapshots.clear()

    @property
    def count(self) -> int:
        """Return the number of stored snapshots."""
        return len(self._snapshots)
