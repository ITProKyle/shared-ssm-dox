"""Test ssm_dox_builder.models.document."""
# pylint: disable=no-self-use,unsubscriptable-object
from typing import Dict

import pytest
from pydantic import ValidationError

from ssm_dox_builder.models.document import SsmDocumentDataModel
from ssm_dox_builder.models.main_steps import AwsRunShellScript
from ssm_dox_builder.models.parameter import SsmDocumentParameterDataModel


class TestSsmDocumentDataModel:
    """Test SsmDocumentDataModel."""

    steps = [
        AwsRunShellScript(
            action="aws:runShellScript",
            inputs={"runCommand": ['echo "Hello world"']},
            name="test",
        )
    ]

    def test_optional_fields(self) -> None:
        """Test optional fields."""
        obj = SsmDocumentDataModel(
            schemaVersion="2.3",
            description="test",
            parameters={"Param": {"type": "String", "default": "something"}},
            mainSteps=self.steps,
        )
        assert obj.schemaVersion == "2.3"
        assert obj.description == "test"
        assert isinstance(obj.parameters["Param"], SsmDocumentParameterDataModel)  # type: ignore
        assert obj.mainSteps == self.steps

    def test_optional_fields_default(self) -> None:
        """Test optional fields default values."""
        obj = SsmDocumentDataModel(mainSteps=self.steps)
        assert obj.schemaVersion == "2.2"
        assert obj.description is None
        assert obj.parameters is None

    @pytest.mark.parametrize("kwargs", [{}])  # type: ignore
    def test_require_fields(self, kwargs: Dict[str, str]) -> None:
        """Test required fields."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentDataModel.parse_obj(kwargs)
        assert len(excinfo.value.errors()) == 1

    @pytest.mark.parametrize("value", ["2.2"])
    def test_schema_version_supported(self, value: str) -> None:
        """Test schemaVersion supported."""
        obj = SsmDocumentDataModel(schemaVersion=value, mainSteps=self.steps)
        assert obj.schemaVersion == value

    @pytest.mark.parametrize("value", ["0.3", "1.2"])
    def test_schema_version_unsupported(self, value: str) -> None:
        """Test schemaVersion unsupported."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentDataModel(schemaVersion=value, mainSteps=self.steps)
        assert len(excinfo.value.errors()) == 1
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("schemaVersion",)
        assert error["type"] == "value_error"
