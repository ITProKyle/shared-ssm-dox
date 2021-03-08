"""Pytest configuration, fixtures, and plugins."""
# pylint: disable=redefined-outer-name
from __future__ import annotations

from pathlib import Path

import pytest


def pytest_addoption(parser):  # type: ignore
    """Add pytest CLI options."""
    parser.addoption(
        "--functional",
        action="store_true",
        default=False,
        help="run only functional tests",
    )
    parser.addoption(
        "--integration",
        action="store_true",
        default=False,
        help="run only integration tests",
    )
    parser.addoption(
        "--unit",
        action="store_true",
        default=False,
        help="run only unit tests",
    )


@pytest.fixture(scope="session")
def integration_tests_dir(tests_dir: Path) -> Path:
    """Return a path object to the integration tests directory."""
    return tests_dir / "integration"


@pytest.fixture(scope="session")
def root_dir() -> Path:
    """Return a path object to the root directory."""
    return Path(__file__).parent.parent


@pytest.fixture(scope="session")
def tests_dir(root_dir: Path) -> Path:
    """Return a path object to the tests directory."""
    return root_dir / "tests"


@pytest.fixture(scope="session")
def unit_test_dir(tests_dir: Path) -> Path:
    """Return a path object to the unit tests directory."""
    return tests_dir / "unit"
