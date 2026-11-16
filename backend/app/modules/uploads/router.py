"""Upload router — generate Cloudinary signatures and upload images."""
from __future__ import annotations

from fastapi import APIRouter, Depends, File, Form, UploadFile

from app.core.deps import get_current_user_id
from app.core.exceptions import success_response
from app.modules.uploads import service
from app.modules.uploads.schemas import SignUploadRequest, VerifyUploadRequest

router = APIRouter()


@router.post("/sign")
async def sign_upload(
    body: SignUploadRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Generate a Cloudinary signed upload payload for the client."""
    data = service.get_upload_signature(
        body.type, body.content_type, body.size, user_id
    )
    return success_response(data)


@router.post("/image", status_code=201)
async def upload_image(
    file: UploadFile = File(...),
    upload_type: str = Form("scan"),
    _user_id: str = Depends(get_current_user_id),
):
    """Upload an image file to Cloudinary via backend and return URL metadata."""
    contents = await file.read()
    data = await service.upload_image_bytes(
        contents=contents,
        filename=file.filename or "scan.jpg",
        content_type=file.content_type or "",
        upload_type=upload_type,
    )
    return success_response(data, status_code=201)


@router.post("/verify")
async def verify_upload(
    body: VerifyUploadRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Verify that a Cloudinary upload exists (placeholder)."""
    # TODO: call Cloudinary Admin API to verify public_id exists.
    return success_response({"public_id": body.public_id, "verified": True})
