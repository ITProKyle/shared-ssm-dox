"""AWS SSM Document data model."""
from __future__ import annotations

from typing import Dict, List, Optional

from pydantic import validator

from .base import BaseModel
from .main_steps import AnyMainStep
from .parameter import SsmDocumentParameterDataModel


class SsmDocumentDataModel(BaseModel):
    """AWS SSM Document data model."""

    schemaVersion: str = "2.2"
    description: Optional[str] = None
    parameters: Optional[Dict[str, SsmDocumentParameterDataModel]] = None
    mainSteps: List[AnyMainStep]

    @validator("schemaVersion")
    @classmethod
    def _validate_supported_schema_version(cls, v: str) -> str:
        """Validate the schema version is supported."""
        split_version = tuple(int(i) for i in v.split("."))
        if split_version < (2, 2):
            raise ValueError("this tool only supports schemaVersion >= 2.2")
        return v
