"""Test ssm_dox_builder.models.main_steps.aws_runshellscript."""
# pylint: disable=no-member,no-self-use
from typing import Dict

import pytest
from pydantic import ValidationError

from ssm_dox_builder.models.main_steps.aws_runshellscript import (
    AwsRunShellScript,
    AwsRunShellScriptInputs,
)


class TestAwsRunShellScript:
    """Test AwsRunShellScript."""

    action = "aws:runShellScript"

    def test_optional_fields(self) -> None:
        """Test optional fields."""
        precondition = {"StringEquals": ["something"]}
        obj = AwsRunShellScript(
            action=self.action,
            inputs={"finallyStep": True},
            name="test",
            precondition=precondition,
        )
        assert obj.action == "aws:runShellScript"
        assert isinstance(obj.inputs, AwsRunShellScriptInputs)
        assert obj.inputs.finallyStep is True
        assert obj.name == "test"
        assert obj.precondition == precondition

    def test_optional_fields_default(self) -> None:
        """Test optional fields default values."""
        obj = AwsRunShellScript(
            action=self.action,
            name="test",
        )
        assert obj.action == "aws:runShellScript"
        assert not obj.inputs
        assert obj.precondition is None

    @pytest.mark.parametrize("kwargs", [{"action": action}, {"name": "test"}])
    def test_require_fields(self, kwargs: Dict[str, str]) -> None:
        """Test required fields."""
        with pytest.raises(ValidationError) as excinfo:
            AwsRunShellScript.parse_obj(kwargs)
        assert len(excinfo.value.errors()) == 1


class TestAwsRunShellScriptInputs:
    """Test AwsRunShellScriptInputs."""

    def test_optional_fields(self) -> None:
        """Test optional fields."""
        commands = ["echo Hello World", "exit 0"]
        obj = AwsRunShellScriptInputs(
            runCommand=commands, timeoutSeconds="300", workingDirectory="./test"
        )
        assert obj.runCommand == commands
        assert obj.timeoutSeconds == "300"
        assert obj.workingDirectory == "./test"

    def test_optional_fields_default(self) -> None:
        """Test optional fields default values."""
        obj = AwsRunShellScriptInputs()
        assert obj.runCommand == []
        assert obj.timeoutSeconds is None
        assert obj.workingDirectory is None
