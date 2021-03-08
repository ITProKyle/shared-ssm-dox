"""Test check command."""
from __future__ import annotations

from typing import TYPE_CHECKING

from click.testing import CliRunner
from mock import MagicMock

from ssm_dox_builder._cli.main import cli
from ssm_dox_builder.constants import RAW_DOX, SHARED_SSM_DOCS
from ssm_dox_builder.dox import Dox
from ssm_dox_builder.exceptions import DocumentDrift
from ssm_dox_builder.finder import Finder

if TYPE_CHECKING:
    from pathlib import Path

    from pytest_mock import MockerFixture

MODULE = "ssm_dox_builder._cli.commands._check"


def test_check(documents_dir: Path, dox_dir: Path, mocker: MockerFixture) -> None:
    """Test check."""
    mock_dox_check = mocker.patch.object(Dox, "check", return_value=None)
    mock_finder = mocker.patch(
        f"{MODULE}.Finder", return_value=Finder(root_dir=dox_dir)
    )
    runner = CliRunner()
    result = runner.invoke(cli, ["check", str(dox_dir), str(documents_dir)])
    mock_finder.assert_called_once_with(root_dir=dox_dir)
    mock_dox_check.assert_called_once_with(documents_dir)
    assert result.exit_code == 0


def test_check_drifted(
    documents_dir: Path, dox_dir: Path, mocker: MockerFixture
) -> None:
    """Test check drifted."""
    mock_dox_check = mocker.patch.object(
        Dox,
        "check",
        side_effect=DocumentDrift(
            document_content=MagicMock(),
            document_path=documents_dir / "ExampleLinux.json",
            dox_content=MagicMock(),
            dox_path=dox_dir,
        ),
    )
    mock_dox_diff = mocker.patch.object(Dox, "diff")
    mock_finder = mocker.patch(
        f"{MODULE}.Finder", return_value=Finder(root_dir=dox_dir)
    )
    runner = CliRunner()
    result = runner.invoke(cli, ["check", str(dox_dir), str(documents_dir)])
    mock_finder.assert_called_once_with(root_dir=dox_dir)
    mock_dox_check.assert_called_once_with(documents_dir)
    mock_dox_diff.assert_called_once_with(documents_dir)
    assert result.exit_code == 1


def test_check_default(dox_dir: Path, mocker: MockerFixture) -> None:
    """Test check default values."""
    mock_dox_check = mocker.patch.object(Dox, "check", return_value=None)
    mock_finder = mocker.patch(
        f"{MODULE}.Finder", return_value=Finder(root_dir=dox_dir)
    )
    runner = CliRunner()
    result = runner.invoke(cli, ["check"])
    mock_finder.assert_called_once_with(root_dir=RAW_DOX)
    mock_dox_check.assert_called_once_with(SHARED_SSM_DOCS)
    assert result.exit_code == 0
