"""CLI logging setup."""
import logging
import os
from functools import cached_property
from typing import Any, Dict

import coloredlogs

LOGGER = logging.getLogger("ssm_dox_builder")

LOG_FORMAT = "[%(programname)s] %(message)s"
LOG_FORMAT_VERBOSE = logging.BASIC_FORMAT
LOG_FIELD_STYLES = {
    "asctime": {},
    "hostname": {},
    "levelname": {},
    "message": {},
    "name": {},
    "prefix": {},
    "programname": {},
}
LOG_LEVEL_STYLES = {
    "critical": {"color": "red", "bold": True},
    "debug": {"color": "green"},
    "error": {"color": "red"},
    "info": {},
    "notice": {"color": "yellow"},
    "spam": {"color": "green", "faint": True},
    "success": {"color": "green", "bold": True},
    "verbose": {"color": "cyan"},
    "warning": {"color": 214},
}


class LogSettings:
    """CLI log settings."""

    ENV = {
        "field_styles": os.getenv("LOG_FIELD_STYLES"),
        "fmt": os.getenv("LOG_FORMAT"),
        "level_styles": os.getenv("LOG_LEVEL_STYLES"),
    }

    def __init__(
        self, *, debug: int = 0, no_color: bool = False, verbose: bool = False
    ):
        """Instantiate class.

        Args:
            debug: Debug level.
            no_color: Disable color in logs.
            verbose: Whether to display verbose logs.

        """
        self.debug = debug
        self.no_color = no_color
        self.verbose = verbose

    @property
    def coloredlogs(self) -> Dict[str, Any]:
        """Return settings for coloredlogs."""
        return {
            "fmt": self.fmt,
            "field_styles": self.field_styles,
            "level_styles": self.level_styles,
        }

    @cached_property
    def fmt(self) -> str:
        """Return log record format.

        If "LOG_FORMAT" exists in the environment, it will be used.

        """
        fmt = self.ENV["fmt"]
        if isinstance(fmt, str):
            return fmt
        if self.debug or self.no_color or self.verbose:
            return LOG_FORMAT_VERBOSE
        return LOG_FORMAT

    @cached_property
    def field_styles(self) -> Dict[str, Any]:
        """Return log field styles.

        If "LOG_FIELD_STYLES" exists in the environment, it will be
        used to update the LOG_FIELD_STYLES.

        """
        if self.no_color:
            return {}

        result = LOG_FIELD_STYLES.copy()
        if self.ENV["field_styles"]:
            result.update(
                coloredlogs.parse_encoded_styles(self.ENV["field_styles"])  # type: ignore
            )
        return result

    @cached_property
    def level_styles(self) -> Dict[str, Any]:
        """Return log level styles.

        If "LOG_LEVEL_STYLES" exists in the environment, it will be
        used to update the LOG_LEVEL_STYLES.

        """
        if self.no_color:
            return {}

        result = LOG_LEVEL_STYLES.copy()
        if self.ENV["level_styles"]:
            result.update(
                coloredlogs.parse_encoded_styles(self.ENV["level_styles"])  # type: ignore
            )
        return result

    @cached_property
    def log_level(self) -> int:
        """Return log level to use."""
        if self.debug:
            return logging.DEBUG
        if self.verbose:
            return logging.DEBUG
        return logging.INFO


def setup_logging(
    *, debug: int = 0, no_color: bool = False, verbose: bool = False
) -> None:
    """Configure log settings for CLI.

    Args:
        debug: Debug level (0-2).
        no_color: Whether to use colorized logs.
        verbose: Use verbose logging.

    """
    settings = LogSettings(debug=debug, no_color=no_color, verbose=verbose)

    coloredlogs.install(  # type: ignore
        settings.log_level, logger=LOGGER, **settings.coloredlogs
    )
    LOGGER.debug("runway log level: %s", LOGGER.getEffectiveLevel())

    if settings.debug == 2:
        coloredlogs.install(  # type: ignore
            settings.log_level,
            logger=logging.getLogger("botocore"),
            **settings.coloredlogs,
        )
        LOGGER.debug("set dependency log level to debug")
    LOGGER.debug("initalized logging")
