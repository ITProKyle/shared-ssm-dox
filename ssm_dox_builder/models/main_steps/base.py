"""AWS SSM Document mainStep base data model."""
from __future__ import annotations

from typing import Dict, List, Literal, Optional

from ..base import BaseModel


class SsmDocumentMainStepInputs(BaseModel):
    """AWS SSM Document mainStep.inputs base data model."""

    finallyStep: Optional[bool] = None
    onFailure: Optional[Literal["exit", "successAndExit"]] = None
    onSuccess: Optional[Literal["exit"]] = None


class SsmDocumentMainStep(BaseModel):
    """AWS SSM Document mainStep base data model."""

    action: str
    inputs: Optional[SsmDocumentMainStepInputs] = None
    name: str
    precondition: Optional[Dict[str, List[str]]] = None
