"""Utilities."""
from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Optional, Union

if TYPE_CHECKING:
    import click


def click_directory(
    ctx: Optional[click.Context],  # pylint: disable=unused-argument
    param: Optional[click.Parameter],  # pylint: disable=unused-argument
    value: Union[Path, str],
) -> Path:
    """Click callback to convert str to Path and ensure its a directory.

    Args:
        ctx: Click context.
        param: The click parameter.
        value: Value provided to click.

    """
    if isinstance(value, str):
        value = Path(value)
    if value.is_file():
        raise ValueError(f"{value} is a file; expected directory")
    value.mkdir(exist_ok=True, parents=True)
    return value
