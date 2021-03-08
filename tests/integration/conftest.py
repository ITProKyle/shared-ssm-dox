"""Pytest configuration, fixtures, and plugins."""
# pylint: disable=redefined-outer-name
from __future__ import annotations

import logging
import os
from typing import TYPE_CHECKING, Any, Dict, Iterator, Optional

import pytest

if TYPE_CHECKING:
    from pathlib import Path

    from _pytest.config import Config

LOGGER = logging.getLogger(__name__)


@pytest.fixture(scope="session")
def aws_credentials() -> Iterator[None]:
    """Handle change in https://github.com/spulec/moto/issues/1924.

    Ensure AWS SDK finds some (bogus) credentials in the environment and
    doesn't try to use other providers.

    """
    overrides = {
        "AWS_ACCESS_KEY_ID": "testing",
        "AWS_SECRET_ACCESS_KEY": "testing",
        "AWS_DEFAULT_REGION": "us-east-1",
    }
    saved_env: Dict[str, Optional[str]] = {}
    for key, value in overrides.items():
        LOGGER.info("Overriding env var: %s=%s", key, value)
        saved_env[key] = os.environ.get(key, None)
        os.environ[key] = value

    yield

    for key, value in saved_env.items():
        LOGGER.info("Restoring saved env var: %s=%s", key, value)
        if value is None:
            os.environ.pop(key, None)  # handle key missing
        else:
            os.environ[key] = value

    saved_env.clear()


# pylint: disable=unused-argument
def pytest_ignore_collect(path: Any, config: Config) -> bool:
    """Determine if this directory should have its tests collected."""
    if config.option.functional or config.option.unit:
        return True
    return False


@pytest.fixture(scope="package")
def documents_dir(fixture_dir: Path) -> Path:
    """Path to the documents directory inside of fixtures."""
    return fixture_dir / "documents"


@pytest.fixture(scope="package")
def dox_dir(fixture_dir: Path) -> Path:
    """Path to the dox directory inside of fixtures."""
    return fixture_dir / "dox"


@pytest.fixture(scope="package")
def fixture_dir(integration_tests_dir: Path) -> Path:
    """Path to the fixture directory."""
    return integration_tests_dir / "fixtures"
