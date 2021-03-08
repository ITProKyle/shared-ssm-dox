"""Test ssm_dox_builder.models.base."""
# pylint: disable=no-self-use,unneeded-not
import json
from typing import Optional

from ssm_dox_builder.models.base import BaseModel


class SampleModel(BaseModel):
    """Sample model for testing."""

    value: Optional[str] = None


class TestBaseModel:
    """Test BaseModel."""

    def test_bool_false(self) -> None:
        """Test __bool__ False."""
        assert not SampleModel()

    def test_bool_true(self) -> None:
        """Test __bool__ True."""
        assert SampleModel(value="test")

    def test_eq(self) -> None:
        """Test __eq__."""
        assert SampleModel(value="test") == SampleModel(value="test")
        assert not SampleModel(value="test") == SampleModel(value="something")
        assert SampleModel(value="test") == json.dumps({"value": "test"}, indent=4)
        assert not SampleModel(value="test") == json.dumps(
            {"value": "something"}, indent=4
        )
        assert SampleModel(value="test") == {"value": "test"}
        assert not SampleModel(value="test") == {"value": "something"}

    def test_ne(self) -> None:
        """Test __ne__."""
        assert SampleModel(value="test") != SampleModel(value="something")
        assert not SampleModel(value="test") != SampleModel(value="test")
        assert SampleModel(value="test") != json.dumps({"value": "something"}, indent=4)
        assert not SampleModel(value="test") != json.dumps({"value": "test"}, indent=4)
        assert SampleModel(value="test") != {"value": "something"}
        assert not SampleModel(value="test") != {"value": "test"}
