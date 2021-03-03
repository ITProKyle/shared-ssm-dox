"""Build SSM Documents."""
from pathlib import Path

import click

from ...constants import RAW_DOX, SHARED_SSM_DOCS
from ...finder import Finder
from .utils import click_directory


@click.command("build", short_help="build dox")
@click.argument("dox_path", callback=click_directory, default=RAW_DOX)
@click.option(
    "-o",
    "--output",
    callback=click_directory,
    default=SHARED_SSM_DOCS,
    help="Path where built files should be placed.",
    show_default=True,
)
def build(dox_path: Path, output: Path) -> None:
    """Build SSM Documents from Dox."""
    finder = Finder(root_dir=dox_path)
    for dox in finder.dox:
        dox.build(output)
