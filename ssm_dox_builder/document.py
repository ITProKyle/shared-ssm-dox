"""SSM Documents."""
from __future__ import annotations

import logging
from typing import TYPE_CHECKING, Optional, cast

from .exceptions import DocumentDoesNotExist
from .mixins import NestedFileMixin
from .models.document import SsmDocumentDataModel

if TYPE_CHECKING:
    from pathlib import Path

    from mypy_boto3_s3.client import S3Client

    from ._logging import CustomLogger

LOGGER = cast("CustomLogger", logging.getLogger(__name__))


class Document(NestedFileMixin):
    """SSM Document."""

    def __init__(
        self,
        *,
        content: Optional[SsmDocumentDataModel] = None,
        path: Path,
        root_dir: Path,
    ) -> None:
        """Instantiate class.

        Args:
            content: Contents of the Document.
            path: Path to the Document.
            root_dir: The root directory continaing the Document.

        """
        self._content = content
        self.name = path.name
        self.path = path
        self.root = root_dir

    @property
    def content(self) -> SsmDocumentDataModel:
        """Contents of the Document."""
        if not self._content:
            if self.path.is_file():
                self._content = SsmDocumentDataModel.parse_raw(self.path.read_bytes())
            else:
                raise DocumentDoesNotExist(self.path)
        return self._content

    @content.setter
    def content(self, value: SsmDocumentDataModel) -> None:
        """Set the value of contents.

        Args:
            value: New contents of the Document.

        """
        self._content = value

    def json(self, *, exclude_none: bool = True, indent: Optional[int] = 4) -> str:
        """Output contents as a JSON formatted string.

        Args:
            exclude_none: Exclude fields whose value is None.
            indent: Number of spaces per indent level.

        """
        return self.content.json(exclude_none=exclude_none, indent=indent)

    def publish(
        self, client: S3Client, *, bucket: str, prefix: Optional[str] = None
    ) -> None:
        """Publish document to S3.

        Args:
            client: S3 client.
            bucket: Name of the S3 Bucket.
            prefix: A prefix to append to the S3 Object key.

        """
        key = f"{self.relative_path.lstrip('./')}/{self.name}".lstrip("/")
        if prefix:
            key = f"{prefix.rstrip('/')}/{key}"
        client.put_object(
            ACL="private",
            Body=self.json().encode(),
            Bucket=bucket,
            ContentType="application/json",
            Key=key,
        )
        LOGGER.success("published %s to s3://%s/%s", self.name, bucket, key)

    def write(self, content: Optional[SsmDocumentDataModel] = None) -> Path:
        """Write contents to disk.

        Args:
            content: What to write to the file.

        """
        if content:
            self.content = content
        self.path.write_text(self.json() + "\n")  # insert new line at the end
        LOGGER.success("wrote to %s", self.path)
        return self.path
