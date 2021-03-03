"""AWS SSM Document data model."""
from __future__ import annotations

from typing import Dict, List

from pydantic import validator

from .base import BaseModel
from .main_steps import AnyMainStep
from .parameter import SsmDocumentParameterDataModel


class SsmDocument(BaseModel):
    """AWS SSM Document data model."""

    schemaVersion: str
    description: str
    parameters: Dict[str, SsmDocumentParameterDataModel]
    mainSteps: List[AnyMainStep]

    @validator("schemaVersion")
    @classmethod
    def _validate_supported_schema_version(cls, v: str) -> str:
        """Validate the schema version is supported."""
        split_version = tuple(int(i) for i in v.split("."))
        if split_version < (2, 2):
            raise NotImplementedError("this tool only supports schemaVersion >= 2.2")
        return v
