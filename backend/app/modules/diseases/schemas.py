"""Disease schemas."""
from __future__ import annotations

from pydantic import BaseModel


class DiseaseStepSchema(BaseModel):
    step_order: int
    title: str
    description: str


class DiseaseOut(BaseModel):
    id: str
    name: str
    scientific_name: str | None = None
    category: str | None = None
    default_severity: str = "treatable"
    ml_label: str | None = None
    is_healthy: bool = False
    location_hint: str | None = None
    description: str | None = None
    steps: list[DiseaseStepSchema] = []

