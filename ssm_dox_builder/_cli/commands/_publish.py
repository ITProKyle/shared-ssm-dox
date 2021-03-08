"""Publish SSM Documents to S3."""
import logging
from pathlib import Path
from typing import Optional

import boto3
import click

from ...constants import DEFAULT_S3_BUCKET, SHARED_SSM_DOCS
from ...finder import Finder
from .utils import click_directory

LOGGER = logging.getLogger(__name__)


@click.command("publish", short_help="publish documents")
@click.argument("bucket", default=DEFAULT_S3_BUCKET, required=True)
@click.argument("documents_path", callback=click_directory, default=SHARED_SSM_DOCS)
@click.option("-p", "--prefix", default="dev", help="prefix to append to S3 Object key")
@click.option("--profile", default=None, help="AWS profile name")
@click.option("--region", default=None, help="AWS region where the bucket is located")
def publish(
    bucket: str,
    documents_path: Path,
    *,
    prefix: Optional[str] = None,
    profile: Optional[str] = None,
    region: Optional[str] = None,
) -> None:
    """Publish SSM Documents to S3."""
    finder = Finder(root_dir=documents_path)
    session = boto3.Session(profile_name=profile, region_name=region)  # type: ignore
    s3_client = session.client("s3")
    for doc in finder.documents:
        doc.publish(s3_client, bucket=bucket, prefix=prefix)
