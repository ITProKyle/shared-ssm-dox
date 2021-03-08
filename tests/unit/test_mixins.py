"""Test ssm_dox_builder.mixins."""
# pylint: disable=no-self-use
from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

from ssm_dox_builder.mixins import NestedFileMixin

if TYPE_CHECKING:
    from pathlib import Path

MODULE = "ssm_dox_builder.mixins"


class TestNestedFileMixin:
    """Test NestedFileMixin."""

    class SampleClass(NestedFileMixin):
        """Sample class for running tests."""

        def __init__(self, *, path: Path, root_dir: Path) -> None:
            """Instantiate class."""
            self.path = path
            self.root = root_dir

    @pytest.mark.parametrize(
        "path, expected",
        [
            ("something", "./"),
            ("", "./"),
            ("./something/child/file.json", "./something/child"),
        ],
    )
    def test_relative_path(self, expected: str, path: str, tmp_path: Path) -> None:
        """Test relative_path."""
        assert (
            self.SampleClass(path=tmp_path / path, root_dir=tmp_path).relative_path
            == expected
        )
