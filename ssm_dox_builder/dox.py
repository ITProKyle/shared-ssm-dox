"""Objects for working with Dox."""
from __future__ import annotations

import difflib
import logging
from functools import cached_property
from pathlib import Path
from typing import IO, Any

import yaml

from .exceptions import DocumentDrift, TemplateNotFound
from .models.document import SsmDocument

LOGGER = logging.getLogger(__name__)


class DoxLoader(yaml.SafeLoader):
    """Dox YAML loader."""

    def __init__(self, stream: IO[Any]) -> None:
        """Instantiate class."""
        try:
            self._root = Path(stream.name).parent
        except AttributeError:
            self._root = Path.cwd()
        super().__init__(stream)  # type: ignore

    def construct_include_script(self, node: yaml.Node) -> Any:
        """Handle !IncludeScript."""
        script = self._root / str(self.construct_scalar(node))  # type: ignore
        with open(script, "r") as f:
            return [line.rstrip() for line in f.readlines()]


DoxLoader.add_constructor("!IncludeScript", DoxLoader.construct_include_script)  # type: ignore


class Dox:
    """Object representation of a raw SSM Document to be build."""

    def __init__(self, path: Path, root_dir: Path) -> None:
        """Instantiate class.

        Args:
            path: Path to the Dox directory.
            root_dir: The root directory continaing the Dox.

        """
        self.name = path.name
        self.path = path.absolute()
        self.root = root_dir.absolute()

    @cached_property
    def content(self) -> SsmDocument:
        """Content of the Dox."""
        LOGGER.debug("loading %s...", self.template)
        with open(self.template, "r") as f:
            content = yaml.load(f, Loader=DoxLoader)  # type: ignore
        LOGGER.debug("parsing %s with data model...", self.template)
        return SsmDocument.parse_obj(content)

    @cached_property
    def relative_path(self) -> str:
        """Relative location of the Dox directory.

        This can be used to ensure that the SSM Document built from the Dox
        is placed in the same subdirectory.

        """
        return "./" + str(self.path.parent).replace(str(self.root), "").lstrip("/")

    @cached_property
    def template(self) -> Path:
        """Template file."""
        extensions = ["yaml", "yml"]
        for ext in extensions:
            tmp_file = self.path / f"template.{ext}"
            if tmp_file.is_file():
                LOGGER.debug("found template file %s in %s", tmp_file.name, self.path)
                return tmp_file
        raise TemplateNotFound(self.path)

    def build(self, output_path: Path) -> None:
        """Build Dox.

        Args:
            output_path: Path where built document will the saved.

        """
        document_path = self.get_built_document_path(output_path)
        document_path.parent.mkdir(exist_ok=True, parents=True)
        LOGGER.info("building %s...", self.name)
        document_path.write_text(self.content.json(exclude_none=True, indent=4) + "\n")
        LOGGER.info("output %s to %s", self.name, document_path)

    def check(self, output_path: Path) -> None:
        """Check Dox against corresponding built document in output path.

        Args:
            output_path: Path where built documents are stored.

        """
        document = self.get_built_document(output_path)
        document_path = self.get_built_document_path(output_path)
        if self.content != document:
            raise DocumentDrift(
                document_content=document,
                document_path=self.get_built_document_path(output_path),
                dox_content=self.content,
                dox_path=self.template.parent,
            )
        LOGGER.info("%s is up to date", document_path)

    def diff(self, output_path: Path) -> None:
        """Diff Dox and corresponding built document in output path.

        Args:
            output_path: Path where built documents are stored.

        """
        dox_content = self.content.json(exclude_none=True, indent=4).split("\n")
        doc_content = (
            self.get_built_document(output_path)
            .json(exclude_none=True, indent=4)
            .split("\n")
        )
        differ = difflib.Differ()
        print("\n".join(differ.compare(doc_content, dox_content)))

    def get_built_document(self, output_path: Path) -> SsmDocument:
        """Get the built document that corresponds with this Dox in output path.

        Args:
            output_path: Path where built documents are stored.

        """
        return SsmDocument.parse_raw(
            self.get_built_document_path(output_path).read_bytes()
        )

    def get_built_document_path(self, output_path: Path) -> Path:
        """Get the path to the built document that corresponds with this Dox.

        Args:
            output_path: Path where built documents are stored.

        """
        return output_path / self.relative_path / f"{self.name}.json"
