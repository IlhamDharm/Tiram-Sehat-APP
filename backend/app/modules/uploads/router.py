"""Upload router — generate Cloudinary signatures."""
from __future__ import annotations

from fastapi import APIRouter, Depends

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


@router.post("/verify")
async def verify_upload(
    body: VerifyUploadRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Verify that a Cloudinary upload exists (placeholder)."""
    # TODO: call Cloudinary Admin API to verify public_id exists.
    return success_response({"public_id": body.public_id, "verified": True})
