"""Base classes for data models."""
from pydantic import BaseModel as _BaseModel


class BaseModel(_BaseModel):
    """Custom base class for data models."""

    def __bool__(self) -> bool:
        """Calculate the boolean value of the object."""
        return bool(
            self.dict(exclude_defaults=True, exclude_none=True, exclude_unset=True)
        )

    def __eq__(self, other: object) -> bool:
        """Calculate equality (==)."""
        if isinstance(other, BaseModel):
            return self.dict() == other.dict()
        if isinstance(other, str):
            return self.json(exclude_none=True, indent=4) == other
        return self.dict() == other

    def __ne__(self, other: object) -> bool:
        """Calculate inequality (!=)."""
        return not self == other
