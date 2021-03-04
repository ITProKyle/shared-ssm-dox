"""Exceptions."""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pathlib import Path

    from .models.document import SsmDocumentDataModel


class DocumentDoesNotExist(Exception):
    """The document trying to be used does not exist."""

    def __init__(self, path: Path) -> None:
        """Instantiate class.

        Args:
            path: Path that should be a Document but is not.

        """
        self.message = f"Document at path {path} does not exist"
        self.path = path
        super().__init__(self.message)


class DocumentDrift(Exception):
    """The currently loaded Dox does not match a corresponding built SSM Document."""

    def __init__(
        self,
        *,
        document_content: SsmDocumentDataModel,
        document_path: Path,
        dox_content: SsmDocumentDataModel,
        dox_path: Path,
    ) -> None:
        """Instantiate class.

        Args:
            document_content: Content of the built document.
            document_path: Path to the built document.
            dox_content: Content of the loaded Dox.
            dox_path: Path to the Dox directory.

        """
        self.document = document_content
        self.document_path = document_path
        self.dox = dox_content
        self.dox_path = dox_path
        self.message = (
            f"document at path {document_path} does not match Dox "
            f"loaded from {dox_path}"
        )
        super().__init__(self.message)


class TemplateNotFound(Exception):
    """Template not found in Dox directory."""

    def __init__(self, path: Path) -> None:
        """Instantiate class.

        Args:
            path: Path that should have a template but does not.

        """
        self.message = f"could not find a template file in {path}"
        self.path = path
        super().__init__(self.message)
