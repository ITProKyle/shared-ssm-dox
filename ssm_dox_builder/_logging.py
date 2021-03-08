"""Custom logging."""
import logging
from enum import IntEnum
from typing import Any, Text, Union


class LogLevels(IntEnum):  # cov: ignore
    """All available log levels."""

    NOTSET = 0
    DEBUG = 10
    VERBOSE = 15
    INFO = 20
    NOTICE = 25
    WARNING = 30
    SUCCESS = 35
    ERROR = 40
    CRITICAL = 50

    @classmethod
    def has_value(cls, value: int) -> bool:
        """Check if IntEnum has a value."""
        return value in cls._value2member_map_  # pylint: disable=no-member


class CustomLogger(logging.Logger):  # cov: ignore
    """Extend built-in logger with additional levels."""

    def __init__(self, name: str, level: Union[int, Text] = logging.NOTSET) -> None:
        """Instantiate the class.

        Args:
            name: Logger name.
            level: Log level.

        """
        super().__init__(name, level)
        logging.addLevelName(LogLevels.VERBOSE, LogLevels.VERBOSE.name)
        logging.addLevelName(LogLevels.NOTICE, LogLevels.NOTICE.name)
        logging.addLevelName(LogLevels.SUCCESS, LogLevels.SUCCESS.name)

    def notice(self, msg: Union[Exception, str], *args: Any, **kwargs: Any) -> None:
        """Log 'msg % args' with severity `NOTICE`.

        Args:
            msg: String template or exception to use for the log record.

        """
        if self.isEnabledFor(LogLevels.NOTICE):
            self._log(LogLevels.NOTICE, msg, args, **kwargs)

    def success(self, msg: Union[Exception, str], *args: Any, **kwargs: Any) -> None:
        """Log 'msg % args' with severity `SUCCESS`.

        Args:
            msg: String template or exception to use for the log record.

        """
        if self.isEnabledFor(LogLevels.SUCCESS):
            self._log(LogLevels.SUCCESS, msg, args, **kwargs)

    def verbose(self, msg: Union[Exception, str], *args: Any, **kwargs: Any) -> None:
        """Log 'msg % args' with severity `VERBOSE`.

        Args:
            msg: String template or exception to use for the log record.

        """
        if self.isEnabledFor(LogLevels.VERBOSE):
            self._log(LogLevels.VERBOSE, msg, args, **kwargs)
