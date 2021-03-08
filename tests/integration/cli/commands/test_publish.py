"""Test publish command."""
# pylint: disable=unused-argument
from __future__ import annotations

from typing import TYPE_CHECKING

from click.testing import CliRunner
from mock import ANY

from ssm_dox_builder._cli.main import cli
from ssm_dox_builder.constants import DEFAULT_S3_BUCKET, SHARED_SSM_DOCS
from ssm_dox_builder.document import Document
from ssm_dox_builder.finder import Finder

if TYPE_CHECKING:
    from pathlib import Path

    from pytest_mock import MockerFixture

MODULE = "ssm_dox_builder._cli.commands._publish"


def test_publish(
    aws_credentials: None, documents_dir: Path, mocker: MockerFixture, tmp_path: Path
) -> None:
    """Test publish."""
    mock_publish = mocker.patch.object(Document, "publish", return_value=None)
    mock_finder = mocker.patch(
        f"{MODULE}.Finder", return_value=Finder(root_dir=documents_dir)
    )
    runner = CliRunner()
    result = runner.invoke(
        cli, ["publish", "test-bucket", str(documents_dir), "--prefix", "latest"]
    )
    mock_finder.assert_called_once_with(root_dir=documents_dir)
    mock_publish.assert_called_once_with(ANY, bucket="test-bucket", prefix="latest")
    assert result.exit_code == 0


def test_publish_default(
    aws_credentials: None, documents_dir: Path, mocker: MockerFixture, tmp_path: Path
) -> None:
    """Test publish default values."""
    mock_publish = mocker.patch.object(Document, "publish", return_value=None)
    mock_finder = mocker.patch(
        f"{MODULE}.Finder", return_value=Finder(root_dir=documents_dir)
    )
    runner = CliRunner()
    result = runner.invoke(cli, ["publish"])
    mock_finder.assert_called_once_with(root_dir=SHARED_SSM_DOCS)
    mock_publish.assert_called_once_with(ANY, bucket=DEFAULT_S3_BUCKET, prefix="dev")
    assert result.exit_code == 0
