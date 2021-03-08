"""Test ssm_dox_builder.models.main_steps.aws_runpowershellscript."""
# pylint: disable=no-member,no-self-use
from typing import Dict

import pytest
from pydantic import ValidationError

from ssm_dox_builder.models.main_steps.aws_runpowershellscript import (
    AwsRunPowerShellScript,
    AwsRunPowerShellScriptInputs,
)


class TestAwsRunPowerShellScript:
    """Test AwsRunPowerShellScript."""

    action = "aws:runPowerShellScript"

    def test_optional_fields(self) -> None:
        """Test optional fields."""
        precondition = {"StringEquals": ["something"]}
        obj = AwsRunPowerShellScript(
            action=self.action,
            inputs={"finallyStep": True},
            name="test",
            precondition=precondition,
        )
        assert obj.action == "aws:runPowerShellScript"
        assert isinstance(obj.inputs, AwsRunPowerShellScriptInputs)
        assert obj.inputs.finallyStep is True
        assert obj.name == "test"
        assert obj.precondition == precondition

    def test_optional_fields_default(self) -> None:
        """Test optional fields default values."""
        obj = AwsRunPowerShellScript(
            action=self.action,
            name="test",
        )
        assert obj.action == "aws:runPowerShellScript"
        assert not obj.inputs
        assert obj.precondition is None

    @pytest.mark.parametrize("kwargs", [{"action": action}, {"name": "test"}])
    def test_require_fields(self, kwargs: Dict[str, str]) -> None:
        """Test required fields."""
        with pytest.raises(ValidationError) as excinfo:
            AwsRunPowerShellScript.parse_obj(kwargs)
        assert len(excinfo.value.errors()) == 1


class TestAwsRunPowerShellScriptInputs:
    """Test AwsRunPowerShellScriptInputs."""

    def test_optional_fields(self) -> None:
        """Test optional fields."""
        commands = ["echo Hello World", "exit 0"]
        obj = AwsRunPowerShellScriptInputs(
            runCommand=commands, timeoutSeconds="300", workingDirectory="./test"
        )
        assert obj.runCommand == commands
        assert obj.timeoutSeconds == "300"
        assert obj.workingDirectory == "./test"

    def test_optional_fields_default(self) -> None:
        """Test optional fields default values."""
        obj = AwsRunPowerShellScriptInputs()
        assert obj.runCommand == []
        assert obj.timeoutSeconds is None
        assert obj.workingDirectory is None
