"""Test ssm_dox_builder.models.main_steps.base."""
# pylint: disable=no-self-use
from typing import Any, Dict, Optional

import pytest
from pydantic import ValidationError

from ssm_dox_builder.models.main_steps.base import (
    SsmDocumentMainStep,
    SsmDocumentMainStepInputs,
)


class TestSsmDocumentMainStep:
    """Test SsmDocumentMainStep."""

    def test_optional_fields(self) -> None:
        """Test optional fields."""
        precondition = {"StringEquals": ["something"]}
        obj = SsmDocumentMainStep(
            action="something",
            inputs={"finallyStep": True},
            name="test",
            precondition=precondition,
        )
        assert obj.action == "something"
        assert isinstance(obj.inputs, SsmDocumentMainStepInputs)
        assert obj.inputs.finallyStep is True
        assert obj.name == "test"
        assert obj.precondition == precondition

    def test_optional_fields_default(self) -> None:
        """Test optional fields default values."""
        obj = SsmDocumentMainStep(
            action="something",
            name="test",
        )
        assert obj.inputs is None
        assert obj.precondition is None

    @pytest.mark.parametrize(
        "kwargs",
        [{"action": "something"}, {"name": "test"}],  # type: ignore
    )
    def test_require_fields(self, kwargs: Dict[str, Any]) -> None:
        """Test required fields."""
        with pytest.raises(ValidationError):
            SsmDocumentMainStep.parse_obj(kwargs)


class TestSsmDocumentMainStepInputs:
    """Test SsmDocumentMainStepInputs."""

    @pytest.mark.parametrize("value", ["exit", "successAndExit", None])
    def test_on_failure_supported(self, value: Optional[str]) -> None:
        """Test onFailure."""
        assert SsmDocumentMainStepInputs(onFailure=value).onFailure == value

    def test_on_failure_unsupported(self) -> None:
        """Test onFailure."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentMainStepInputs(onFailure="invalid")
        assert len(excinfo.value.errors()) == 1
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("onFailure",)
        assert error["type"] == "value_error.const"

    @pytest.mark.parametrize("value", ["exit", None])
    def test_on_success_supported(self, value: Optional[str]) -> None:
        """Test onSuccess."""
        assert SsmDocumentMainStepInputs(onSuccess=value).onSuccess == value

    def test_on_success_unsupported(self) -> None:
        """Test onSuccess."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentMainStepInputs(onSuccess="invalid")
        assert len(excinfo.value.errors()) == 1
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("onSuccess",)
        assert error["type"] == "value_error.const"

    def test_require_fields(self) -> None:
        """Test required fields."""
        obj = SsmDocumentMainStepInputs()  # no required parameters
        assert not obj.finallyStep
        assert not obj.onFailure
        assert not obj.onSuccess
