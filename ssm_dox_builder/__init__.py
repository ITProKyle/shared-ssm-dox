"""SSM Document builder."""
import logging
from importlib.metadata import PackageNotFoundError, version

from ._logging import CustomLogger

logging.setLoggerClass(CustomLogger)

try:
    __version__ = version("shared-ssm-dox")
except PackageNotFoundError:
    # package not installed
    __version__ = "0.0.0"
