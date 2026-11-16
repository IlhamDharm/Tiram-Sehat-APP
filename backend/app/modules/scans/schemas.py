"""Scan schemas."""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class ScanStepIn(BaseModel):
    title: str
    description: str = ""


class ScanStepOut(BaseModel):
    step_order: int
    title: str
    description: str


class CreateScanRequest(BaseModel):
    rak_id: str
    column_no: int
    batch_id: str | None = None
    disease_id: str | None = None
    diagnosis_name: str | None = None
    scientific_name: str | None = None
    ml_label: str | None = None
    client_id: str | None = None
    confidence: float | None = Field(None, ge=0, le=100)
    severity: str = "treatable"
    infection_location: str | None = None
    scan_method: str = "camera"
    scanned_at: str
    image_public_id: str | None = None
    image_url: str | None = None
    image_version: int | None = None
    image_thumbnail_url: str | None = None
    status: str | None = None
    status_note: str | None = None
    status_tag: str | None = None
    steps: list[ScanStepIn] | None = None


class BatchSyncScanRequest(BaseModel):
    scans: list[CreateScanRequest]


class UpdateScanRequest(BaseModel):
    status: str | None = None
    status_note: str | None = None
    status_tag: str | None = None


class CreateActionRequest(BaseModel):
    action_type: str
    to_status: str | None = None
    note: str | None = None
    tag: str | None = None


class ScanOut(BaseModel):
    id: str
    code: str | None = None
    user_id: str
    baglog_id: str | None = None
    rak_id: str
    column_no: int
    batch_id: str | None = None
    disease_id: str | None = None
    diagnosis_name: str | None = None
    scientific_name: str | None = None
    confidence: float | None = None
    infection_location: str | None = None
    severity: str
    scan_method: str
    image_url: str | None = None
    image_thumbnail_url: str | None = None
    status: str
    status_note: str | None = None
    status_tag: str | None = None
    scanned_at: str
    steps: list[ScanStepOut] = []


class ScanListQuery(BaseModel):
    status: str | None = None
    rak_id: str | None = None
    disease_id: str | None = None
    limit: int = Field(20, ge=1, le=100)
    cursor: str | None = None
