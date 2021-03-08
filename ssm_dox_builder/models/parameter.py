"""AWS SSM Document parameter data model."""
from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional, Union, cast

from pydantic import validator

from .base import BaseModel

_ParameterType = Literal[
    "Boolean", "Integer", "MapList", "String", "StringList", "StringMap"
]


class SsmDocumentParameterDataModel(BaseModel):
    """AWS SSM Document parameter data model."""

    type: _ParameterType  # needs to be defined first for validators

    allowedPattern: Optional[str] = None
    allowedValues: Optional[List[str]] = None
    default: Optional[
        Union[
            bool,
            List[Dict[str, str]],
            List[str],
            Dict[str, str],
            Dict[str, List[str]],
            int,
            str,
        ]
    ] = None
    description: Optional[str] = None
    displayType: Optional[Literal["textarea", "testfield"]] = None
    maxChars: Optional[int] = None
    maxItems: Optional[int] = None
    minChars: Optional[int] = None
    minItems: Optional[int] = None

    @validator("default")
    @classmethod
    def _validate_default(cls, v: Any, values: Dict[str, Any]) -> Any:
        """Validate the schema version is supported."""
        if v is None:
            return v
        param_type = cast(_ParameterType, values.get("type"))
        if param_type == "Boolean":
            return bool(v)
        if param_type == "Integer":
            return int(v)
        if param_type == "MapList" and not isinstance(v, list):
            raise TypeError(f"{type(v)}; expected type List[Dict[str, str]]")
        if param_type == "String":
            return str(v)  # type: ignore
        if param_type == "StringList" and not isinstance(v, list):
            raise TypeError(f"{type(v)}; expected type List[str]")
        if param_type == "StringMap" and not isinstance(v, dict):
            raise TypeError(f"{type(v)}; expected type Dict[str, str]")  # type: ignore
        return v
