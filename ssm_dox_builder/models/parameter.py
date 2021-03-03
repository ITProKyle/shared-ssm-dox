"""AWS SSM Document parameter data model."""
from __future__ import annotations

from typing import Dict, List, Literal, Optional, Union

from .base import BaseModel


class SsmDocumentParameterDataModel(BaseModel):
    """AWS SSM Document parameter data model."""

    allowedPattern: Optional[str] = None
    allowedValues: Optional[List[str]] = None
    default: Optional[
        Union[
            bool,
            Dict[str, str],
            Dict[str, List[str]],
            int,
            List[Dict[str, str]],
            List[str],
            str,
        ]
    ] = None
    description: Optional[str] = None
    displayType: Optional[Literal["textarea", "testfield"]] = None
    maxChars: Optional[int] = None
    maxItems: Optional[int] = None
    minChars: Optional[int] = None
    minItems: Optional[int] = None
    type: Literal["Boolean", "Integer", "MapList", "String", "StringList", "StringMap"]
