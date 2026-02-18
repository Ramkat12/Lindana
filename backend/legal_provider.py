# api/legal_aid_providers.py - Separate router for provider endpoints
from typing import List, Optional
import uuid
import logging
import traceback
from fastapi import APIRouter, Depends, HTTPException, status
from uuid import UUID
from sqlalchemy.orm import Session, joinedload
from pydantic import BaseModel

from database import get_db
from models import LegalAidProvider, ExpertiseArea
import json
import logging
import traceback
import uuid

from sqlalchemy import UUID, func


from schema import RealTimeGPSLogCreate, RealTimeGPSLogShow

from schema import ActivityCreate, ActivityShow, LocationSharingSessionCreate

from schema import PoliceLocationCreate
from schema import DangerZoneCreate, PoliceLocationUpdate,UserDistributionResponse, DangerZoneDataPoint, DangerZonesResponse, AnalyticsResponse,showExpertiseArea
from schema import CreateLegalAidRequest, ShowLegalAidRequest
from schema import UserResponse
import legal_provider
import legal_tips
import Africas_talking
import certifi  
import os
import requests
import httpx
import legal_requests
from calulate_distance import calculate_distance
from sqlalchemy.orm import joinedload


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from uuid import UUID 

from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordRequestForm
from database import get_db
import crud
import models
import schema
from models import Activity,  EmergencyContact, EmergencyLog, LegalAidRequest, LocationSMSRequest, LocationSharingSession,DangerZone, PoliceLocation,  RealTimeGPSLog, SMSRequest, User, LegalAidProvider, UserTokenTable, LegalAidTokenTable
from schema import CreateUser, CreateLegalAid, changepassword, TokenSchema, ShowUser, ShowLegalAid,editprofile,DangerZoneBase, DangerZoneResponse,PoliceLocationBase, PoliceLocationResponse, ProximityAlert, ProximityResponse
from crud import verify_password, get_password_hash, create_access_token, create_refresh_token,get_current_user
from fastapi import Request
import requests
from auth import jwt_bearer, decodeJWT
import jwt
from dotenv import load_dotenv
import os
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from safety_tips_page import router as safety_tips_router 
from paypal import paypal_router
from admin_routes import router as admin_router

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, timedelta
import httpx
import Africas_talking
import os
from schema import SMSRequest, LocationSMSRequest, SMSResponse, LocationSMSResponse
import asyncio
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse

import certifi
import httpx
load_dotenv()


# Correct router for legal aid providers
router = APIRouter(prefix="", tags=["legal-aid-providers"])

from datetime import datetime

class LegalAidProviderResponse(BaseModel):
    id: UUID
    full_name: str
    phone_number: str
    email: str
    status: str
    profile_image: Optional[str] = None
    psk_number: str
    about: Optional[str] = None
    expertise_area_ids: Optional[List[str]] = []
    created_at: datetime  # Change this from str to datetime

    class Config:
        from_attributes = True

# Get all verified providers
@router.get("/api/legal-aid-providers", response_model=List[LegalAidProviderResponse])
async def get_all_providers(
    skip: int = 0,
    limit: int = 100,
    status_filter: Optional[str] = "verified",
    db: Session = Depends(get_db)
):
    """Get all legal aid providers"""
    try:
        query = db.query(LegalAidProvider).options(
            joinedload(LegalAidProvider.expertise_areas)
        )
        
        if status_filter:
            query = query.filter(LegalAidProvider.status == status_filter)
        
        providers = query.order_by(LegalAidProvider.created_at.desc()).offset(skip).limit(limit).all()
        
        return providers
    except Exception as e:
        logging.error(f"Error fetching providers: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching providers: {str(e)}"
        )

# Get a specific provider by ID
@router.get("/api/legal-aid-providers/{provider_id}", response_model=LegalAidProviderResponse)
async def get_provider_by_id(provider_id: UUID, db: Session = Depends(get_db)):
    """Get a specific legal aid provider by ID"""
    try:
        provider = db.query(LegalAidProvider).options(
            joinedload(LegalAidProvider.expertise_areas)
        ).filter(LegalAidProvider.id == provider_id).first()
        
        if not provider:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Legal aid provider with ID {provider_id} not found"
            )
        
        return provider
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error fetching provider: {str(e)}")
        logging.error(f"Provider ID: {provider_id}")
        logging.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching provider: {str(e)}"
        )

# Get providers by expertise area
@router.get("/api/legal-aid-providers/expertise/{expertise_id}")
async def get_providers_by_expertise(
    expertise_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Get providers by expertise area"""
    try:
        providers = db.query(LegalAidProvider).options(
            joinedload(LegalAidProvider.expertise_areas)
        ).join(
            LegalAidProvider.expertise_areas
        ).filter(
            ExpertiseArea.id == expertise_id,
            LegalAidProvider.status == "verified"
        ).order_by(LegalAidProvider.created_at.desc()).offset(skip).limit(limit).all()
        
        return providers
    except Exception as e:
        logging.error(f"Error fetching providers by expertise: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching providers by expertise: {str(e)}"
        )

# Search providers
@router.get("/api/legal-aid-providers/search/")
async def search_providers(
    q: str,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Search providers by name or expertise"""
    try:
        providers = db.query(LegalAidProvider).options(
            joinedload(LegalAidProvider.expertise_areas)
        ).filter(
            LegalAidProvider.status == "verified"
        ).filter(
            LegalAidProvider.full_name.ilike(f"%{q}%")
        ).order_by(LegalAidProvider.created_at.desc()).offset(skip).limit(limit).all()
        
        return providers
    except Exception as e:
        logging.error(f"Error searching providers: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error searching providers: {str(e)}"
        )
    

@router.get("/legal-aid-providers", response_model=List[ShowLegalAid])
async def get_legal_aid_providers(db: Session = Depends(get_db)):
    """Get all active legal aid providers with their expertise areas"""
    try:
        providers = db.query(LegalAidProvider).filter(
            LegalAidProvider.status == "verified"
        ).all()
        
        return providers
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching legal aid providers: {str(e)}"
        )

@router.get("/legal-aid-providers/{provider_id}", response_model=ShowLegalAid)
async def get_legal_aid_provider(provider_id: UUID, db: Session = Depends(get_db)):
    """Get a specific legal aid provider by ID"""
    try:
        provider = db.query(LegalAidProvider).filter(
            LegalAidProvider.id == provider_id
        ).first()
        
        if not provider:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Legal aid provider not found"
            )
        
        return provider
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching legal aid provider: {str(e)}"
        )
@router.post("/legal-aid-requests", response_model=ShowLegalAidRequest)
async def create_legal_aid_request(
    request_data: CreateLegalAidRequest,
    db: Session = Depends(get_db)
):
    """Create a new legal aid request"""
    try:
        # Verify that the user exists
        user = db.query(User).filter(User.id == request_data.user_id).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Verify that the legal aid provider exists and is active
        provider = db.query(LegalAidProvider).filter(
            LegalAidProvider.id == request_data.legal_aid_provider_id,
            LegalAidProvider.status == "verified"
        ).first()
        if not provider:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Legal aid provider not found or inactive"
            )
        
        # Create the request
        new_request = LegalAidRequest(
            user_id=request_data.user_id,
            legal_aid_provider_id=request_data.legal_aid_provider_id,
            title=request_data.title,
            description=request_data.description,
            status="pending"
        )
        
        db.add(new_request)
        db.commit()
        db.refresh(new_request)
        
        return new_request
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating legal aid request: {str(e)}"
        )
