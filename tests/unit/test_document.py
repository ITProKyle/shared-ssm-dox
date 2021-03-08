"""Test ssm_dox_builder.document."""
# pylint: disable=no-self-use
from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Optional

import boto3
import pytest
from botocore.stub import Stubber
from mock import MagicMock

from ssm_dox_builder.document import Document
from ssm_dox_builder.exceptions import DocumentDoesNotExist
from ssm_dox_builder.models.document import SsmDocumentDataModel

if TYPE_CHECKING:
    from pytest_mock import MockerFixture


class TestDocument:
    """Test Document."""

    def test_content(self, documents_dir: Path) -> None:
        """Test content."""
        path = documents_dir / "ExampleLinux.json"
        obj = Document(path=path, root_dir=documents_dir)
        assert obj.content == SsmDocumentDataModel.parse_raw(path.read_bytes())

    def test_content_document_does_not_exist(self, documents_dir: Path) -> None:
        """Test content raises DocumentDoesNotExist."""
        path = documents_dir / "DocumentDoesNotExist.json"
        obj = Document(path=path, root_dir=documents_dir)
        with pytest.raises(DocumentDoesNotExist) as excinfo:
            obj.content  # pylint: disable=pointless-statement
        assert excinfo.value.path == path

    def test_content_provided(self, documents_dir: Path) -> None:
        """Test content provided."""
        content = SsmDocumentDataModel.parse_raw(
            (documents_dir / "ExampleLinux.json").read_bytes()
        )
        path = documents_dir / "DocumentDoesNotExist.json"
        obj = Document(content=content, path=path, root_dir=documents_dir)
        assert obj.content == content

    def test_content_setter(self, documents_dir: Path) -> None:
        """Test content.setter."""
        content_linux = SsmDocumentDataModel.parse_raw(
            (documents_dir / "ExampleLinux.json").read_bytes()
        )
        content_windows = SsmDocumentDataModel.parse_raw(
            (documents_dir / "ExampleWindows.json").read_bytes()
        )
        path = documents_dir / "ExampleLinux.json"
        obj = Document(path=path, root_dir=documents_dir)
        assert obj.content == content_linux
        obj.content = content_windows
        assert obj.content == content_windows

    def test_init(self, documents_dir: Path) -> None:
        """Test __init__."""
        path = documents_dir / "ExampleLinux.json"
        obj = Document(path=path, root_dir=documents_dir)
        assert obj._content is None  # pylint: disable=protected-access
        assert obj.name == path.name
        assert obj.path == path
        assert obj.root == documents_dir

    def test_json(self, documents_dir: Path) -> None:
        """Test json."""
        content = MagicMock(autospec=SsmDocumentDataModel)
        content.json = MagicMock(return_value="success")
        path = documents_dir / "ExampleLinux.json"
        obj = Document(content=content, path=path, root_dir=documents_dir)
        assert obj.json() == content.json.return_value
        content.json.assert_called_once_with(exclude_none=True, indent=4)
        obj.json(exclude_none=False, indent=2)
        content.json.assert_called_with(exclude_none=False, indent=2)

    @pytest.mark.parametrize(
        "relative_path, prefix, expected_prefix",
        [
            ("./rel", None, "rel"),
            ("rel", "prefix", "prefix/rel"),
            ("./", "prefix", "prefix"),
            ("./", None, ""),
        ],
    )
    def test_publish(
        self,
        expected_prefix: str,
        documents_dir: Path,
        mocker: MockerFixture,
        relative_path: str,
        prefix: Optional[str],
    ) -> None:
        """Test publish."""
        bucket = "test-bucket"
        client = boto3.client("s3")
        stubber = Stubber(client)
        path = documents_dir / "ExampleLinux.json"
        mocker.patch.object(Document, "relative_path", relative_path)
        key = f"{expected_prefix}/{path.name}".lstrip("/")
        obj = Document(path=path, root_dir=documents_dir)

        stubber.add_response(
            "put_object",
            {},
            {
                "ACL": "private",
                "Body": obj.json().encode(),
                "Bucket": bucket,
                "ContentType": "application/json",
                "Key": key,
            },
        )

        with stubber:
            obj.publish(client, bucket=bucket, prefix=prefix)

    def test_write(self, documents_dir: Path, mocker: MockerFixture) -> None:
        """Test write."""
        mocker.patch.object(
            Document,
            "content",
            SsmDocumentDataModel.parse_raw(
                (documents_dir / "ExampleLinux.json").read_bytes()
            ),
        )
        mock_path = MagicMock(autospec=Path)
        mock_path.write_text = MagicMock()
        obj = Document(path=mock_path, root_dir=documents_dir)
        assert obj.write() == mock_path
        mock_path.write_text.assert_called_once_with(obj.json() + "\n")

    def test_write_provided(self, documents_dir: Path, mocker: MockerFixture) -> None:
        """Test write."""
        new_content = SsmDocumentDataModel.parse_raw(
            (documents_dir / "ExampleWindows.json").read_bytes()
        )
        mocker.patch.object(
            Document,
            "content",
            SsmDocumentDataModel.parse_raw(
                (documents_dir / "ExampleLinux.json").read_bytes()
            ),
        )
        mock_path = MagicMock(autospec=Path)
        mock_path.write_text = MagicMock()
        obj = Document(path=mock_path, root_dir=documents_dir)
        assert obj.write(new_content) == mock_path
        assert obj.content == new_content
        mock_path.write_text.assert_called_once_with(obj.json() + "\n")
