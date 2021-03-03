"""AWS SSM Document mainStep data models."""
from typing import Union

from .aws_runpowershellscript import AwsRunPowerShellScript
from .aws_runshellscript import AwsRunShellScript

AnyMainStep = Union[AwsRunPowerShellScript, AwsRunShellScript]

__all__ = ["AwsRunPowerShellScript", "AwsRunShellScript"]
