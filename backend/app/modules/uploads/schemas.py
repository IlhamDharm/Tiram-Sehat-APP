"""Upload schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field


class SignUploadRequest(BaseModel):
    type: str = Field("scan", description="scan | avatar | batch")
    content_type: str = Field("image/jpeg", description="MIME type")
    size: int = Field(0, ge=0, le=10_485_760, description="File size in bytes")


class SignUploadResponse(BaseModel):
    cloud_name: str
    api_key: str
    upload_preset: str
    folder: str
    public_id: str
    timestamp: int
    signature: str
    expires_at: int


class VerifyUploadRequest(BaseModel):
    public_id: str
