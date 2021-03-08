"""Mixins."""
from __future__ import annotations

import os
from functools import cached_property
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pathlib import Path


class NestedFileMixin:
    """Mixin for a file that may be nested in directories for handling paths."""

    path: Path
    root: Path

    @cached_property
    def relative_path(self) -> str:
        """Relative location of a file in a directory.

        This can be used when moving a file between directories to ensure that
        their path relative to the new root directory remains the same as for
        the original root directory.

        """
        if self.path == self.root:
            return "./"
        return "./" + str(self.path.parent).replace(str(self.root), "").lstrip(os.sep)
