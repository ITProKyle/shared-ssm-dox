"""SSM Document Builder CLI entrypoint."""
from __future__ import annotations

from typing import Any, Dict

import click

from .. import __version__
from . import commands
from .logs import setup_logging

CLICK_CONTEXT_SETTINGS: Dict[str, Any] = {
    "help_option_names": ["-h", "--help"],
    "max_content_width": 999,
}


@click.group(context_settings=CLICK_CONTEXT_SETTINGS)
@click.version_option(__version__, message="%(version)s")
def cli() -> None:
    """SSM Document Builder CLI."""
    setup_logging()


for cmd in commands.__all__:
    cli.add_command(getattr(commands, cmd))  # type: ignore
