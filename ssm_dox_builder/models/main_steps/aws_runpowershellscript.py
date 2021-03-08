"""AWS SSM Document mainStep aws:runPowerShellScript data model.

https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-runPowerShellScript

"""
from __future__ import annotations

from typing import List, Literal, Optional

from .base import SsmDocumentMainStep, SsmDocumentMainStepInputs


class AwsRunPowerShellScriptInputs(SsmDocumentMainStepInputs):
    """AWS SSM Document mainStep aws:runPowerShellScript inputs data model."""

    runCommand: List[str] = []
    timeoutSeconds: Optional[str] = None
    workingDirectory: Optional[str] = None


class AwsRunPowerShellScript(SsmDocumentMainStep):
    """AWS SSM Document mainStep aws:runPowerShellScript data model.

    https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-runPowerShellScript

    """

    action: Literal["aws:runPowerShellScript"]
    inputs: AwsRunPowerShellScriptInputs = AwsRunPowerShellScriptInputs()
