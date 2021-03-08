"""Test ssm_dox_builder.dox."""
# pylint: disable=no-self-use
from __future__ import annotations

import os
from pathlib import Path
from typing import TYPE_CHECKING, Optional

import pytest
import yaml
from mock import MagicMock

from ssm_dox_builder.document import Document
from ssm_dox_builder.dox import Dox, DoxLoader
from ssm_dox_builder.exceptions import DocumentDrift, TemplateNotFound
from ssm_dox_builder.models.document import SsmDocumentDataModel

if TYPE_CHECKING:
    from pytest_mock import MockerFixture

MODULE = "ssm_dox_builder.dox"


class TestDox:
    """Test Dox."""

    def test_build(self, dox_dir: Path, mocker: MockerFixture, tmp_path: Path) -> None:
        """Test build."""
        mock_write = mocker.patch.object(Document, "write", return_value=None)
        document = Document(path=tmp_path / "ExampleLinux.json", root_dir=tmp_path)
        mock_get_document = mocker.patch.object(
            Dox, "get_document", return_value=document
        )
        obj = Dox(path=dox_dir / "ExampleLinux", root_dir=dox_dir)
        assert obj.build(tmp_path) == document.path
        mock_get_document.assert_called_once_with(tmp_path)
        mock_write.assert_called_once_with(content=obj.content)

    def test_check(
        self, documents_dir: Path, dox_dir: Path, mocker: MockerFixture
    ) -> None:
        """Test check."""
        document = Document(
            path=documents_dir / "ExampleLinux.json", root_dir=documents_dir
        )
        mock_get_document = mocker.patch.object(
            Dox, "get_document", return_value=document
        )
        obj = Dox(path=dox_dir / "ExampleLinux", root_dir=dox_dir)

        assert not obj.check(documents_dir)
        mock_get_document.assert_called_once_with(documents_dir)

    def test_check_document_drift(
        self, documents_dir: Path, dox_dir: Path, mocker: MockerFixture
    ) -> None:
        """Test check raise DocumentDrift."""
        document = Document(
            path=documents_dir / "ExampleWindows.json", root_dir=documents_dir
        )
        mocker.patch.object(Dox, "get_document", return_value=document)
        obj = Dox(path=dox_dir / "ExampleLinux", root_dir=dox_dir)

        with pytest.raises(DocumentDrift) as excinfo:
            assert not obj.check(documents_dir)
        assert excinfo.value.document == document.content
        assert excinfo.value.document_path == document.path
        assert excinfo.value.dox == obj.content
        assert excinfo.value.dox_path == obj.path

    def test_content(self, documents_dir: Path, dox_dir: Path) -> None:
        """Test content."""
        document = SsmDocumentDataModel.parse_raw(
            (documents_dir / "ExampleLinux.json").read_bytes()
        )
        path = dox_dir / "ExampleLinux"
        obj = Dox(path=path, root_dir=dox_dir)
        assert isinstance(obj.content, SsmDocumentDataModel)
        assert obj.content == document

    def test_diff(
        self, documents_dir: Path, dox_dir: Path, mocker: MockerFixture
    ) -> None:
        """Test diff."""
        document = Document(
            path=documents_dir / "ExampleLinux.json", root_dir=documents_dir
        )
        mock_get_document = mocker.patch.object(
            Dox, "get_document", return_value=document
        )
        mock_differ = MagicMock()
        mock_differ.compare = MagicMock(return_value=["success"])
        mocker.patch(f"{MODULE}.difflib", Differ=MagicMock(return_value=mock_differ))
        obj = Dox(path=dox_dir / "ExampleLinux", root_dir=dox_dir)

        assert not obj.diff(documents_dir)
        mock_get_document.assert_called_once_with(documents_dir)
        mock_differ.compare.assert_called_once_with(
            obj.json().split("\n"), document.json().split("\n")
        )

    def test_get_document(
        self, documents_dir: Path, dox_dir: Path, mocker: MockerFixture
    ) -> None:
        """Test get_document."""
        doc_path = documents_dir / "ExampleLinux.json"
        mock_get_document_path = mocker.patch.object(
            Dox, "get_document_path", return_value=doc_path
        )
        obj = Dox(path=dox_dir / "ExampleLinux", root_dir=dox_dir)
        result = obj.get_document(documents_dir)
        mock_get_document_path.assert_called_once_with(documents_dir)
        assert result.path == doc_path
        assert result.root == documents_dir

    def test_get_document_path(
        self, documents_dir: Path, dox_dir: Path, mocker: MockerFixture
    ) -> None:
        """Test get_document_path."""
        mocker.patch.object(Dox, "relative_path", "")
        assert (
            Dox(path=dox_dir / "ExampleLinux", root_dir=dox_dir).get_document_path(
                documents_dir
            )
            == documents_dir / "ExampleLinux.json"
        )

    def test_init(self, dox_dir: Path) -> None:
        """Test __init__."""
        path = dox_dir / "ExampleLinux"
        obj = Dox(path=path, root_dir=dox_dir)
        assert obj.name == path.name
        assert obj.path == path
        assert obj.root == dox_dir

    def test_json(self, documents_dir: Path, mocker: MockerFixture) -> None:
        """Test json."""
        content = MagicMock(autospec=SsmDocumentDataModel)
        content.json = MagicMock(return_value="success")
        mocker.patch.object(Dox, "content", content)
        path = documents_dir / "ExampleLinux.json"
        obj = Dox(path=path, root_dir=documents_dir)
        assert obj.json() == content.json.return_value
        content.json.assert_called_once_with(exclude_none=True, indent=4)
        obj.json(exclude_none=False, indent=2)
        content.json.assert_called_with(exclude_none=False, indent=2)

    @pytest.mark.parametrize("ext", ["yaml", "yml"])
    def test_template(self, ext: str, tmp_path: Path) -> None:
        """Test template."""
        template_path = tmp_path / f"template.{ext}"
        template_path.touch()
        obj = Dox(path=tmp_path, root_dir=tmp_path)
        assert obj.template == template_path

    @pytest.mark.parametrize(
        "file_name", ["template", "template.json", "something.yml", None]
    )
    def test_template_template_not_found(
        self, file_name: Optional[str], tmp_path: Path
    ) -> None:
        """Test template raise TemplateNotFound."""
        if file_name:
            (tmp_path / file_name).touch()
        obj = Dox(path=tmp_path, root_dir=tmp_path)
        with pytest.raises(TemplateNotFound) as excinfo:
            assert not obj.template
        assert excinfo.value.path == tmp_path


class TestDoxLoader:
    """Test DoxLoader."""

    def test_include_script(self, dox_dir: Path) -> None:
        """Test !IncludeScript."""
        dox_path = dox_dir / "ExampleLinux"
        raw_file = dox_path / "template.yml"
        expected = [
            line.rstrip() for line in (dox_path / "script.sh").read_text().split("\n")
        ]
        expected.pop()  # remove empty last line
        with open(raw_file, "r") as f:
            result = yaml.load(f, Loader=DoxLoader)
        assert result["mainSteps"][0]["inputs"]["runCommand"] == expected

    def test_include_script_cwd(self, tmp_path: Path) -> None:
        """Test !IncludeScript cwd."""
        orig = Path.cwd().absolute()  # cache original working direcory
        os.chdir(tmp_path)  # cd to tmp_path
        try:
            script_file = tmp_path / "test_script.sh"
            expected = ['echo "Hello world"']
            script_file.write_text("\n".join(expected))

            result = yaml.load(
                f"value: !IncludeScript {script_file.name}", Loader=DoxLoader
            )
            assert result["value"] == expected
        finally:
            os.chdir(orig)  # revert working directory

    def test_linux_only(self, dox_dir: Path) -> None:
        """Test !LinuxOnly."""
        raw_file = dox_dir / "ExampleLinux" / "template.yml"
        expected = {"StringEquals": ["platformType", "Linux"]}
        with open(raw_file, "r") as f:
            result = yaml.load(f, Loader=DoxLoader)
        assert result["mainSteps"][0]["precondition"] == expected

    def test_windows_only(self, dox_dir: Path) -> None:
        """Test !WindowsOnly."""
        raw_file = dox_dir / "ExampleWindows" / "template.yml"
        expected = {"StringEquals": ["platformType", "Windows"]}
        with open(raw_file, "r") as f:
            result = yaml.load(f, Loader=DoxLoader)
        assert result["mainSteps"][0]["precondition"] == expected
