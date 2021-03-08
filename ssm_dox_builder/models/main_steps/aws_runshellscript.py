"""AWS SSM Document mainStep aws:runShellScript data model.

https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-runShellScript

"""
from __future__ import annotations

from typing import List, Literal, Optional

from .base import SsmDocumentMainStep, SsmDocumentMainStepInputs


class AwsRunShellScriptInputs(SsmDocumentMainStepInputs):
    """AWS SSM Document mainStep aws:runShellScript inputs data model."""

    runCommand: List[str] = []
    timeoutSeconds: Optional[str] = None
    workingDirectory: Optional[str] = None


class AwsRunShellScript(SsmDocumentMainStep):
    """AWS SSM Document mainStep aws:runShellScript data model.

    https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-runShellScript

    """

    action: Literal["aws:runShellScript"]
    inputs: AwsRunShellScriptInputs = AwsRunShellScriptInputs()
