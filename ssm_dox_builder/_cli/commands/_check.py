"""Check SSM Documents."""
import logging
from pathlib import Path

import click

from ...constants import RAW_DOX, SHARED_SSM_DOCS
from ...exceptions import DocumentDrift
from ...finder import Finder
from .utils import click_directory

LOGGER = logging.getLogger(__name__)


@click.command("check", short_help="check dox")
@click.argument("dox_path", callback=click_directory, default=RAW_DOX)
@click.argument("documents_path", callback=click_directory, default=SHARED_SSM_DOCS)
@click.pass_context
def check(ctx: click.Context, documents_path: Path, dox_path: Path) -> None:
    """Check SSM Documents to ensure they are current with the Dox."""
    finder = Finder(root_dir=dox_path)
    for dox in finder.dox:
        try:
            dox.check(documents_path)
        except DocumentDrift as err:
            LOGGER.error(err)
            dox.diff(documents_path)
            ctx.exit(1)
    LOGGER.info("all documents are up to date")
