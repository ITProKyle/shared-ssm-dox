"""Test ssm_dox_builder.finder."""
# pylint: disable=no-self-use
from __future__ import annotations

from typing import TYPE_CHECKING

from ssm_dox_builder.document import Document
from ssm_dox_builder.dox import Dox
from ssm_dox_builder.finder import Finder

if TYPE_CHECKING:
    from pathlib import Path

    from pytest_mock import MockerFixture


class TestFinder:
    """Test Finder."""

    def test_documents(self, tmp_path: Path) -> None:
        """Test documents."""
        json0 = tmp_path / "json0.json"
        json0.touch()
        json1 = tmp_path / "child" / "json1.json"
        json1.mkdir(exist_ok=True, parents=True)
        json1.touch()

        documents = Finder(tmp_path).documents
        assert len(documents) == 2
        assert isinstance(documents[0], Document)
        assert documents[0].path == json0
        assert documents[0].root == tmp_path
        assert isinstance(documents[1], Document)
        assert documents[1].path == json1
        assert documents[1].root == tmp_path

    def test_dox(self, mocker: MockerFixture, tmp_path: Path) -> None:
        """Test dox."""
        mock_has_template = mocker.patch.object(
            Finder, "has_template", return_value=True
        )
        mock_subdirectories = mocker.patch.object(
            Finder, "subdirectories", [tmp_path / "something"]
        )
        obj = Finder(tmp_path)
        assert len(obj.dox) == 1
        mock_has_template.assert_called_once_with(mock_subdirectories[0])
        dox = obj.dox[0]
        assert isinstance(dox, Dox)
        assert dox.path == mock_subdirectories[0]
        assert dox.root == tmp_path

    def test_has_template(self, tmp_path: Path) -> None:
        """Test has_template."""
        dir0 = tmp_path / "parent0"
        dir0.mkdir(exist_ok=True, parents=True)
        assert not Finder.has_template(dir0)

        dir1 = tmp_path / "parent0" / "child0"
        dir1.mkdir(exist_ok=True, parents=True)
        (dir1 / "template.yml").touch()
        assert not Finder.has_template(dir0)
        assert Finder.has_template(dir1)

        dir2 = tmp_path / "parent1"
        dir2.mkdir(exist_ok=True, parents=True)
        (dir2 / "template").touch()
        assert not Finder.has_template(dir2)

    def test_init(self, tmp_path: Path) -> None:
        """Test __init__."""
        obj = Finder(tmp_path)
        assert obj.root == tmp_path

    def test_scandir(self, tmp_path: Path) -> None:
        """test scandir."""
        expected = [
            tmp_path / "parent0",
            tmp_path / "parent1",
            tmp_path / "parent2",
            tmp_path / "parent0" / "child0",
            tmp_path / "parent0" / "child0" / "subchild0",
            tmp_path / "parent1" / "child0",
            tmp_path / "parent1" / "child1",
        ]
        for d in expected:
            d.mkdir(exist_ok=True, parents=True)
        assert Finder.scandir(tmp_path) == expected

    def test_subdirectories(self, mocker: MockerFixture, tmp_path: Path) -> None:
        """Test subdirectories."""
        mock_scandir = mocker.patch.object(Finder, "scandir", return_value=[tmp_path])
        obj = Finder(tmp_path)
        assert obj.subdirectories == mock_scandir.return_value
        mock_scandir.assert_called_once_with(tmp_path)
