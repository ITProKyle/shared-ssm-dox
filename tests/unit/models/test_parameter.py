"""Test ssm_dox_builder.models.parameter."""
# pylint: disable=no-self-use
from typing import Any, Optional

import pytest
from pydantic import ValidationError

from ssm_dox_builder.models.parameter import SsmDocumentParameterDataModel


class TestSsmDocumentParameterDataModel:
    """Test SsmDocumentParameterDataModel."""

    @pytest.mark.parametrize("value", [False, 0, "False", ""])
    def test_default_bool_false(self, value: Any) -> None:
        """Test default bool."""
        obj = SsmDocumentParameterDataModel.parse_obj(
            {"default": value, "type": "Boolean"}
        )
        assert obj.default is False

    @pytest.mark.parametrize("value", ["test", 13, "13", True, "True"])
    def test_default_bool_true(self, value: Any) -> None:
        """Test default bool."""
        obj = SsmDocumentParameterDataModel.parse_obj(
            {"default": value, "type": "Boolean"}
        )
        assert obj.default is True

    @pytest.mark.parametrize(
        "provided, expected", [(13, 13), ("13", 13), (True, 1), (False, 0)]
    )
    def test_default_int(self, provided: Any, expected: int) -> None:
        """Test default."""
        obj = SsmDocumentParameterDataModel.parse_obj(
            {"default": provided, "type": "Integer"}
        )
        assert obj.default == expected

    @pytest.mark.parametrize("value", [([]), ([{"k": "v"}])])
    def test_default_map_list(self, value: Any) -> None:
        """Test default."""
        obj = SsmDocumentParameterDataModel.parse_obj(
            {"default": value, "type": "MapList"}
        )
        assert obj.default == value

    def test_default_map_list_type_error(self) -> None:
        """Test default."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentParameterDataModel.parse_obj(
                {"default": "test", "type": "MapList"}
            )
        assert len(excinfo.value.errors()) == 1
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("default",)
        assert error["type"] == "type_error"

    @pytest.mark.parametrize("value", [None, "test", 13, "13", True, False])
    def test_default_string(self, value: Any) -> None:
        """Test default."""
        obj = SsmDocumentParameterDataModel.parse_obj(
            {"default": value, "type": "String"}
        )
        if value is None:
            assert not obj.default
            return
        assert obj.default == str(value)

    @pytest.mark.parametrize("value", [([]), (["test"])])
    def test_default_string_list(self, value: Any) -> None:
        """Test default."""
        obj = SsmDocumentParameterDataModel.parse_obj(
            {"default": value, "type": "StringList"}
        )
        assert obj.default == value

    def test_default_string_list_type_error(self) -> None:
        """Test default."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentParameterDataModel.parse_obj(
                {"default": "test", "type": "StringList"}
            )
        assert len(excinfo.value.errors()) == 1
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("default",)
        assert error["type"] == "type_error"

    @pytest.mark.parametrize("value", [{}, {"key": "val"}])  # type: ignore
    def test_default_string_map(self, value: Any) -> None:
        """Test default."""
        obj = SsmDocumentParameterDataModel.parse_obj(
            {"default": value, "type": "StringMap"}
        )
        assert obj.default == value

    def test_default_string_map_type_error(self) -> None:
        """Test default."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentParameterDataModel.parse_obj(
                {"default": "test", "type": "StringMap"}
            )
        assert len(excinfo.value.errors()) == 1
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("default",)
        assert error["type"] == "type_error"

    def test_required_fields(self) -> None:
        """Test required fields."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentParameterDataModel()
        assert len(excinfo.value.errors()) == 1  # only 1 required field
        assert excinfo.value.errors()[0]["loc"] == ("type",)

    @pytest.mark.parametrize("display_type", ["textarea", "testfield", None])
    def test_display_type_supported(self, display_type: Optional[str]) -> None:
        """Test displayType supported value."""
        assert (
            SsmDocumentParameterDataModel.parse_obj(
                {"displayType": display_type, "type": "String"}
            ).displayType
            == display_type
        )

    def test_display_type_unsupported(self) -> None:
        """Test displayType unsupported value."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentParameterDataModel.parse_obj(
                {"displayType": "invalid", "type": "String"}
            )
        assert len(excinfo.value.errors()) == 1
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("displayType",)
        assert error["type"] == "value_error.const"

    @pytest.mark.parametrize(
        "param_type",
        ["Boolean", "Integer", "MapList", "String", "StringList", "StringMap"],
    )
    def test_type_supported(self, param_type: str) -> None:
        """Test type supported value."""
        assert (
            SsmDocumentParameterDataModel.parse_obj({"type": param_type}).type
            == param_type
        )

    def test_type_unsupported(self) -> None:
        """Test type unsupported value."""
        with pytest.raises(ValidationError) as excinfo:
            SsmDocumentParameterDataModel.parse_obj({"type": "Invalid"})
        error = excinfo.value.errors()[0]
        assert error["loc"] == ("type",)
        assert error["type"] == "value_error.const"
