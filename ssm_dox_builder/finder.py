"""Explore a directory."""
from __future__ import annotations

import logging
import os
from functools import cached_property
from pathlib import Path
from typing import List

from .document import Document
from .dox import Dox

LOGGER = logging.getLogger(__name__)


class Finder:
    """Explore a directory."""

    def __init__(self, root_dir: Path) -> None:
        """Instantiate class.

        Args:
            root_dir: The root directory to explore.

        """
        self.root = root_dir

    @cached_property
    def documents(self) -> List[Document]:
        """List of documents found in the root directory."""
        result = [
            Document(path=f, root_dir=self.root) for f in self.root.rglob("*.json")
        ]
        LOGGER.info("found %s document(s)", len(result))
        return result

    @cached_property
    def dox(self) -> List[Dox]:
        """List of Dox found in the root directory."""
        result = [
            Dox(path=d, root_dir=self.root)
            for d in self.subdirectories
            if self.has_template(d)
        ]
        LOGGER.info("found %s dox", len(result))
        return result

    @cached_property
    def subdirectories(self) -> List[Path]:
        """List of subdirectories."""
        return self.scandir(self.root)

    @staticmethod
    def has_template(path: Path) -> bool:
        """Check if a directory contains a template file.

        Args:
            path: Path to check for a template file.

        """
        if list(path.glob("template.*")):
            return True
        return False

    @staticmethod
    def scandir(path: Path) -> List[Path]:
        """Scan directory to find all subdirectories.

        Args:
            path: Path to scan.

        """
        dirs: List[Path] = [Path(d.path) for d in os.scandir(path) if d.is_dir()]
        for d in list(dirs):
            dirs.extend(Finder.scandir(d))
        return dirs
