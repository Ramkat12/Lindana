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

client = httpx.Client(verify=certifi.where())

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(safety_tips_router)
app.include_router(paypal_router)
app.include_router(admin_router)
# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
security = HTTPBearer()
sms_service = Africas_talking.AfricasTalkingService()
app.include_router(legal_tips.router)
app.include_router(legal_requests.router)
app.include_router(legal_provider.router)


ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))
REFRESH_TOKEN_EXPIRE_MINUTES = int(os.getenv("REFRESH_TOKEN_EXPIRE_MINUTES", 60 * 24 * 7))  # 7 days
ALGORITHM = "HS256"
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_REFRESH_SECRET_KEY = os.getenv("JWT_REFRESH_SECRET_KEY")

# Serve uploaded images as static files
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

router = APIRouter()

active_connections = {}


@app.get("/")
async def root():
    return {"message": "Hello from FastAPI!"}

@app.middleware("http")
async def log_request(request: Request, call_next):
    body = await request.body()
    logging.info(f"Request body: {body.decode('utf-8')}")
    
    response = await call_next(request)
    return response

@app.post("/register/user", response_model=ShowUser)
def register_user(user: CreateUser, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(
        (models.User.phone_number == user.phone_number) |
        (models.User.email == user.email)
    ).first()
    print(user.dict())
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already exists"
        )
    created_user = crud.create_user(db, user)
    return created_user

@app.post("/register/legal_aid_provider", response_model=ShowLegalAid)
def register_legal_aid(legal_aid: CreateLegalAid, db: Session = Depends(get_db)):
    print("Received:", legal_aid.dict())  # Show incoming data
    existing_legal_aid_provider = db.query(models.LegalAidProvider).filter(
        (models.LegalAidProvider.phone_number == legal_aid.phone_number) |
        (models.LegalAidProvider.email == legal_aid.email)
    ).first()
    if existing_legal_aid_provider:
        print("Duplicate found:", existing_legal_aid_provider)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account exists"
        )
    created_legal_aid = crud.create_legal_aid(db, legal_aid)
    print("Created:", created_legal_aid)
    return created_legal_aid




@app.post("/login", response_model=TokenSchema)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # Query with explicit role_id selection
    user = db.query(models.User).filter(
        (models.User.email == form_data.username.strip().lower()) |
        (models.User.phone_number == form_data.username)
    ).first()

    legal_aid = db.query(models.LegalAidProvider).filter(
        (models.LegalAidProvider.email == form_data.username) |
        (models.LegalAidProvider.phone_number == form_data.username)
    ).first()

    authenticated_user = None
    user_type = None
    role_id = None  # Initialize explicitly

    if user and verify_password(form_data.password, user.password_hash):
        authenticated_user = user
        user_type = "user"
        # Force refresh from database to ensure role_id is loaded
        db.refresh(user)
        role_id = user.role_id
        print(f"USER - ID: {user.id}, role_id: {role_id}")
        
    elif legal_aid and verify_password(form_data.password, legal_aid.password_hash):
        authenticated_user = legal_aid
        user_type = "legal_aid"
        # Force refresh from database to ensure role_id is loaded
        db.refresh(legal_aid)
        role_id = legal_aid.role_id
        print(f"LEGAL_AID - ID: {legal_aid.id}, role_id: {role_id}")

    if not authenticated_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid credentials"
        )

    # Double-check role_id is not None
    if role_id is None:
        print(f"WARNING: role_id is None for user {authenticated_user.id}")
        # Query specifically for role_id
        if user_type == "user":
            role_result = db.query(models.User.role_id).filter(models.User.id == authenticated_user.id).first()
        else:
            role_result = db.query(models.LegalAidProvider.role_id).filter(models.LegalAidProvider.id == authenticated_user.id).first()
        
        role_id = role_result[0] if role_result else None
        print(f"Direct role_id query result: {role_id}")

    access_token = create_access_token(str(authenticated_user.id), user_type, role_id)
    refresh_token = create_refresh_token(str(authenticated_user.id))
    user_id = authenticated_user.id

    if user_type == "user":
        token_db = UserTokenTable(
            user_id=authenticated_user.id,
            access_token=access_token,
            refresh_token=refresh_token,
            status=True
        )
    else:  # legal_aid
        token_db = LegalAidTokenTable(
            provider_id=authenticated_user.id,
            access_token=access_token,
            refresh_token=refresh_token,
            status=True
        )

    db.add(token_db)
    db.commit()
    db.refresh(token_db)
    
    print(f"FINAL RESPONSE - role_id: {role_id}")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role_id": role_id,
        
    }


@app.get("/api/users/{user_id}", response_model=UserResponse)
def get_user_by_id(user_id: UUID, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.post("/google/login", response_model=TokenSchema)
def google_login(token: str, db: Session = Depends(get_db)):
    response = requests.get(f'https://oauth2.googleapis.com/tokeninfo?id_token={token}')
    if response.status_code != 200:
        raise HTTPException(status_code=400, detail="Invalid Google credentials")

    user_info = response.json()
    email = user_info['email']

    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        user = models.User(
            email=email,
            full_name=user_info.get('name', ''),
            password_hash="",  # Google auth user has no password
            role_id=2  # example role id for normal user
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    access_token = create_access_token(user.id, "user")
    refresh_token = create_refresh_token(user.id)

    token_db = UserTokenTable(
        user_id=user.id,
        access_token=access_token,
        refresh_token=refresh_token,
        status=True
    )
    db.add(token_db)
    db.commit()
    db.refresh(token_db)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token
    }



@app.get('/getusers', response_model=list[ShowUser])
def getusers(db: Session = Depends(get_db), token: str = Depends(jwt_bearer)):
    users = db.query(models.User).all()
    return users
@app.get("/expertise-areas", response_model=List[showExpertiseArea])
async def get_expertise_areas(db: Session = Depends(get_db)):
    expertise_areas = db.query(models.ExpertiseArea).all()
    if not expertise_areas:
        # Instead of 404, return empty list for better UX
        return [ {"id": 1, "name": "Criminal Law"},
        {"id": 2, "name": "International Law"},
        {"id": 3, "name": "Human Rights Law"},
        {"id": 4, "name": "Commercial Law"},
        {"id": 5, "name": "Health Law"},
        {"id": 6, "name": "Divorce and Family Law"},
        ]
    
    return expertise_areas                  
    # 
@app.post('/changePassword')
def change_password(request: changepassword, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == request.email).first()
    legal_aid = db.query(models.LegalAidProvider).filter(models.LegalAidProvider.email == request.email).first()

    account = user or legal_aid
    if not account:
        raise HTTPException(status_code=400, detail="Account not found")

    if not verify_password(request.old_password, account.password_hash):
        raise HTTPException(status_code=400, detail="Invalid old password")

    account.password_hash = get_password_hash(request.new_password)
    db.commit()

    return {"message": "Password changed successfully"}


@app.post('/editProfile')
def edit_profile(request: editprofile, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    # Get current user info from JWT token
    user_id = current_user["sub"]
    user_type = current_user["user_type"]
    
    # Query based on user type from JWT
    if user_type == "user":
        account = db.query(models.User).filter(models.User.id == user_id).first()
    else:  # legal_aid
        account = db.query(models.LegalAidProvider).filter(models.LegalAidProvider.id == user_id).first()
    
    if not account:
        raise HTTPException(status_code=400, detail="Account not found")

    # Verify old password
    if not verify_password(request.old_password, account.password_hash):
        raise HTTPException(status_code=400, detail="Invalid old password")

    # Update based on user type and role
    if user_type == "user":
        # Update basic user fields
        account.password_hash = get_password_hash(request.new_password)
        account.full_name = request.full_name
        account.email = request.email
        account.phone_number = request.phone_number
        
        # Handle profile image if provided
        if hasattr(request, 'profile_image') and request.profile_image:
            account.profile_image = request.profile_image
        
        # Handle emergency contacts for regular users (role_id 5)
        if account.role_id == 5:
            # Check if emergency contact exists
            emergency_contact = db.query(models.EmergencyContact).filter(
                models.EmergencyContact.user_id == user_id
            ).first()
            
            if emergency_contact:
                # Update existing emergency contact
                emergency_contact.contact_name = request.emergency_contact_name
                emergency_contact.email_contact = request.emergency_contact_email
                emergency_contact.contact_number = request.emergency_contact_number
            else:
                # Create new emergency contact
                new_emergency_contact = models.EmergencyContact(
                    user_id=user_id,
                    contact_name=request.emergency_contact_name,
                    email_contact=request.emergency_contact_email,
                    contact_number=request.emergency_contact_number
                )
                db.add(new_emergency_contact)
    
    elif user_type == "legal_aid":
        # Update legal aid provider fields
        account.password_hash = get_password_hash(request.new_password)
        account.full_name = request.full_name
        account.email = request.email
        account.phone_number = request.phone_number
        
        # Handle expertise area if provided
        if hasattr(request, 'expertise_area') and request.expertise_area:
            account.expertise_area = request.expertise_area
    
    try:
        db.commit()
        db.refresh(account)
        return {"message": "Profile successfully changed"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update profile")



@app.post('/logout')
def logout(token: str = Depends(jwt_bearer), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        user_type = payload.get("user_type")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    if user_type == "user":
        token_record = db.query(UserTokenTable).filter(
            UserTokenTable.user_id == user_id,
            UserTokenTable.access_token == token
        ).first()
    elif user_type == "legal_aid":
        token_record = db.query(LegalAidTokenTable).filter(
            LegalAidTokenTable.provider_id == user_id,
            LegalAidTokenTable.access_token == token
        ).first()
    else:
        raise HTTPException(status_code=400, detail="Unknown user type")

    if not token_record:
        raise HTTPException(status_code=404, detail="Token not found")

    token_record.status = False
    db.commit()

    return {"message": "Logged out successfully"}

@app.get("/emergency-contacts")
def get_emergency_contacts(token: str = Depends(jwt_bearer), db: Session = Depends(get_db)):
    payload = decodeJWT(token)
    if not payload:
        raise HTTPException(status_code=403, detail="Invalid token")

    user_id = payload.get("sub")
    user_type = payload.get("user_type")
    role_id = payload.get("role_id")

    # Only allow users (not legal aid providers) and only those with role_id == 5
    if user_type != "user" or role_id != 5:
        raise HTTPException(
            status_code=403, 
            detail="Emergency contacts are only available for specific user roles"
        )

    # Get emergency contacts for the user
    emergency_contacts = db.query(models.EmergencyContact).filter(
        models.EmergencyContact.user_id == user_id
    ).all()

    # Format the response
    contacts_response = []
    for contact in emergency_contacts:
        contacts_response.append({
            "id": contact.id,
            "contact_name": contact.contact_name,
            "contact_number": contact.contact_number,
            "email_contact": contact.email_contact
        })

    return contacts_response

@app.get("/profile")
def get_profile(token: str = Depends(jwt_bearer), db: Session = Depends(get_db)):
    print(f"DEBUG: Received token: {token[:50]}...")
    
    payload = decodeJWT(token)
    print(f"DEBUG: Decoded payload: {payload}")
    
    if not payload:
        print("DEBUG: Invalid token - payload is None")
        raise HTTPException(status_code=403, detail="Invalid token")
    
    user_id = payload.get("sub")
    user_type = payload.get("user_type")
    role_id = payload.get("role_id")
    
    print(f"DEBUG: user_id={user_id} (type: {type(user_id)})")
    print(f"DEBUG: user_type={user_type}")
    print(f"DEBUG: role_id={role_id}")
    
    if user_type == "user":
        # Try both string and converted types
        print(f"DEBUG: Querying User table with id: {user_id}")
        
        # If your User.id is UUID, you might need to convert
        if isinstance(user_id, str):
            try:
                # If using UUID
                import uuid
                user_uuid = uuid.UUID(user_id)
                user = db.query(models.User).filter(models.User.id == user_uuid).first()
            except:
                # If using string directly  
                user = db.query(models.User).filter(models.User.id == user_id).first()
        else:
            user = db.query(models.User).filter(models.User.id == user_id).first()
        
        print(f"DEBUG: Found user: {user}")
        print(f"DEBUG: User query result - user is None: {user is None}")
        
        if not user:
            # Let's check what users exist
            all_users = db.query(models.User.id, models.User.full_name).limit(5).all()
            print(f"DEBUG: Sample users in database: {all_users}")
            raise HTTPException(status_code=404, detail="User not found")
        
        return {
            "id": str(user.id),  # Convert to string for consistency
            "name": user.full_name,
            "email": user.email,
            "phone_number": user.phone_number,
            "profile_image": user.profile_image,
            "user_type": user_type,
            "role_id": role_id
        }
    
    elif user_type == "legal_aid":
        print(f"DEBUG: Querying LegalAidProvider table with id: {user_id}")
        
        if isinstance(user_id, str):
            try:
                import uuid
                user_uuid = uuid.UUID(user_id)
                # Use joinedload to eagerly load expertise_areas relationship
                legal_aid = db.query(models.LegalAidProvider).options(
                    joinedload(models.LegalAidProvider.expertise_areas)
                ).filter(models.LegalAidProvider.id == user_uuid).first()
            except:
                legal_aid = db.query(models.LegalAidProvider).options(
                    joinedload(models.LegalAidProvider.expertise_areas)
                ).filter(models.LegalAidProvider.id == user_id).first()
        else:
            legal_aid = db.query(models.LegalAidProvider).options(
                joinedload(models.LegalAidProvider.expertise_areas)
            ).filter(models.LegalAidProvider.id == user_id).first()
        
        print(f"DEBUG: Found legal_aid: {legal_aid}")
        
        if not legal_aid:
            all_providers = db.query(models.LegalAidProvider.id, models.LegalAidProvider.full_name).limit(5).all()
            print(f"DEBUG: Sample legal aid providers in database: {all_providers}")
            raise HTTPException(status_code=404, detail="Legal aid provider not found")
        
        # Extract expertise areas as a list of dictionaries or names
        expertise_areas = []
        for area in legal_aid.expertise_areas:
            expertise_areas.append({
                "id": area.id,
                "name": area.name
            })
        
        print(f"DEBUG: Expertise areas found: {expertise_areas}")
        
        return {
            "id": str(legal_aid.id),
            "name": legal_aid.full_name,
            "email": legal_aid.email,
            "phone_number": legal_aid.phone_number,
            "profile_image": getattr(legal_aid, 'profile_image', None),
            "expertise_areas": expertise_areas,  # Changed from expertise_area to expertise_areas
            "user_type": user_type,
            "role_id": role_id
        }
    
    else:
        print(f"DEBUG: Unknown user_type: {user_type}")
        raise HTTPException(status_code=400, detail="Invalid user type")
    
app.get("/view-legal-aid-providers")
def view_legal_aid_providers(db: Session = Depends(get_db)):
    """View all legal aid providers"""
    try:
        legal_aid_providers = db.query(models.LegalAidProvider).all()
        return [ShowLegalAid.from_orm(provider) for provider in legal_aid_providers]
    except Exception as e:
        logger.error(f"Failed to fetch legal aid providers: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to fetch legal aid providers")
    
@app.post("/api/send-emergency-sms")
async def send_emergency_sms(
    request: SMSRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send emergency SMS to specified phone number"""
    try:
        # Send SMS
        sms_result = await sms_service.send_sms(
            phone_number=request.phone_number,
            message=request.message
        )
        
        # Log emergency alert
        emergency_log = EmergencyLog(
            user_id=current_user["user_id"],
            type="emergency",
            message=request.message,
            recipients=[request.phone_number],
            trigger_method="api",
            sms_results=[sms_result]
        )
        # db.add(emergency_log)
        # db.commit()
        
        # Critical logging for emergency
        logger.critical(f"EMERGENCY SMS SENT - User: ({current_user['user_id']}) "
                       f"to {request.phone_number} at {datetime.utcnow()}")
        
        return {
            "success": True,
            "message": "Emergency SMS sent successfully",
            "result": sms_result
        }
        
    except Exception as e:
        logger.error(f"Emergency SMS failed for user {current_user['user_id']}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send emergency SMS: {str(e)}"
        )

@app.post("/api/send-location-sms")
async def send_location_sms(
    request: LocationSMSRequest,
    current_user: dict = Depends(get_current_user)
):
    """Send location sharing SMS"""
    try:
        # Send SMS
        sms_result = await sms_service.send_sms(
            phone_number=request.phone_number,
            message=request.message
        )
        
        logger.info(f"Location SMS sent by user {current_user['user_id']} to {request.phone_number}")
        
        return {
            "success": True,
            "message": "Location SMS sent successfully",
            "result": sms_result
        }
        
    except Exception as e:
        logger.error(f"Location SMS failed for user {current_user['user_id']}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send location SMS: {str(e)}"
        )

@app.delete("/api/emergency-contacts/{contact_id}")
async def delete_emergency_contact(
    contact_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete emergency contact"""
    try:
        # Your existing logic here...
        
        logger.info(f"Emergency contact {contact_id} deleted for user {current_user['user_id']}")
        
        return {"success": True, "message": "Emergency contact deleted successfully"}
        
    except Exception as e:
        logger.error(f"Failed to delete emergency contact {contact_id}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete emergency contact: {str(e)}"
        )

    
@app.get("/api/emergency-logs")
async def get_emergency_logs(
    current_user: dict = Depends(get_current_user),
    limit: int = 50,
    offset: int = 0
):
    """Get emergency activity logs for the user"""
    try:
        # Mock data for demo
        logs = [
            {
                "id": 1,
                "type": "emergency",
                "message": "Emergency alert triggered",
                "recipients": ["+254712345678", "+254787654321"],
                "trigger_method": "shake",
                "created_at": datetime.utcnow()
            }
        ]
        
        return {
            "success": True,
            "logs": logs,
            "total": len(logs)
        }
        
    except Exception as e:
        logger.error(f"Failed to get emergency logs for user {current_user['user_id']}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get emergency logs: {str(e)}"
        )

# Health check endpoint
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "service": "Emergency Alert API"
    }

@app.post("/gps/log-realtime", response_model=RealTimeGPSLogShow)
async def create_gps_log(
    gps_data: RealTimeGPSLogCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Create a new GPS log entry"""
    try:
        logger.info(f"Starting GPS log creation")
        logger.info(f"GPS data received: {gps_data}")
        logger.info(f"Current user: {current_user}")
        
        # Check if current_user is valid
        if not current_user:
            raise HTTPException(status_code=401, detail="User authentication failed")
        
        logger.info(f"User ID: {current_user['user_id']}")
        
        # Validate activity exists and belongs to user
        '''activity = db.query(Activity).filter(
            Activity.id == gps_data.activity_id,
            Activity.user_id == current_user["user_id"]
        ).first()
        
        if not activity:
            raise HTTPException(
                status_code=404, 
                detail="Activity not found or does not belong to user"
            )'''
        
        # Create GPS log entry
        logger.info("Creating GPS log entry...")
        db_gps_log = RealTimeGPSLog(
            user_id=current_user["user_id"],
            activity_id=gps_data.activity_id,
            latitude=gps_data.latitude,
            longitude=gps_data.longitude,
            recorded_at=datetime.utcnow()
        )
        
        logger.info("Adding to database...")
        db.add(db_gps_log)
        
        logger.info("Committing to database...")
        db.commit()
        
        logger.info("Refreshing object...")
        db.refresh(db_gps_log)
        
        logger.info("Adding background task...")
        # Broadcast to active connections in background
        background_tasks.add_task(
            broadcast_location_update,
            current_user["user_id"],
            {
                "user_id": str(current_user["user_id"]),
                "latitude": gps_data.latitude,
                "longitude": gps_data.longitude,
                "timestamp": datetime.utcnow().isoformat(),
                "activity_id": gps_data.activity_id
            }
        )
        
        logger.info("Returning GPS log...")
        return db_gps_log
        
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        # Log the full error details
        logger.error(f"Error creating GPS log: {str(e)}")
        logger.error(f"Error type: {type(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        # Rollback database transaction
        try:
            db.rollback()
            logger.info("Database rollback successful")
        except Exception as rollback_error:
            logger.error(f"Database rollback failed: {rollback_error}")
        
        raise HTTPException(status_code=500, detail=f"Failed to create GPS log: {str(e)}")

@app.get("/gps/logs/{user_id}", response_model=List[RealTimeGPSLogShow])
async def get_user_gps_logs(
    user_id: UUID,
    activity_id: Optional[int] = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get GPS logs for a specific user"""
    try:
        # Check if current user can access these logs (either own logs or shared)
        if str(current_user["user_id"]) != str(user_id):
            # Check if location is shared with current user
            shared_session = db.query(LocationSharingSession).filter(
                LocationSharingSession.user_id == user_id,
                LocationSharingSession.is_active == True,
                LocationSharingSession.expires_at > datetime.utcnow()
            ).first()
            
            if not shared_session:
                raise HTTPException(
                    status_code=403, 
                    detail="Access denied: Location not shared with you"
                )
        
        query = db.query(RealTimeGPSLog).filter(RealTimeGPSLog.user_id == user_id)
        
        if activity_id:
            query = query.filter(RealTimeGPSLog.activity_id == activity_id)
        
        logs = query.order_by(RealTimeGPSLog.recorded_at.desc()).limit(limit).all()
        return logs
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch GPS logs: {str(e)}")

@app.get("/gps/latest/{user_id}")
async def get_latest_location(
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get the latest location for a user"""
    try:
        # Check if current user can access this location
        if str(current_user["user_id"]) != str(user_id):
            # Check if location is shared with current user
            shared_session = db.query(LocationSharingSession).filter(
                LocationSharingSession.user_id == user_id,
                LocationSharingSession.is_active == True,
                LocationSharingSession.expires_at > datetime.utcnow()
            ).first()
            
            if not shared_session:
                raise HTTPException(
                    status_code=403, 
                    detail="Access denied: Location not shared with you"
                )
        
        latest_log = db.query(RealTimeGPSLog)\
            .filter(RealTimeGPSLog.user_id == user_id)\
            .order_by(RealTimeGPSLog.recorded_at.desc())\
            .first()
        
        if not latest_log:
            raise HTTPException(status_code=404, detail="No location data found")
        
        return {
            "user_id": str(latest_log.user_id),
            "latitude": latest_log.latitude,
            "longitude": latest_log.longitude,
            "recorded_at": latest_log.recorded_at.isoformat(),
            "activity_id": latest_log.activity_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch latest location: {str(e)}")

@app.get("/gps/stream/{user_id}")
async def stream_user_location(
    user_id: UUID,
    current_user = Depends(get_current_user)
):
    """Stream real-time location updates for a user"""
    async def event_stream():
        connection_id = f"{current_user['user_id']}_{user_id}"
        
        # Add connection to active connections
        if str(user_id) not in active_connections:
            active_connections[str(user_id)] = set()
        active_connections[str(user_id)].add(connection_id)
        
        try:
            while True:
                # Wait for location updates
                await asyncio.sleep(1)
                
                # Send heartbeat to keep connection alive
                yield f"data: {json.dumps({'type': 'heartbeat', 'timestamp': datetime.utcnow().isoformat()})}\n\n"
                
        except asyncio.CancelledError:
            # Clean up connection
            user_id_str = str(user_id)
            if user_id_str in active_connections:
                active_connections[user_id_str].discard(connection_id)
                if not active_connections[user_id_str]:
                    del active_connections[user_id_str]
            raise
    
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
        }
    )
@app.post("/gps/share", response_model=dict)
async def share_location_with_contacts(
    sharing_data: LocationSharingSessionCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Share real-time location with specified contacts"""
    try:
        # Create sharing session
        expires_at = datetime.utcnow() + timedelta(hours=sharing_data.duration_hours)
        session_token = str(uuid.uuid4())
        
        db_sharing_session = LocationSharingSession(
            user_id=current_user["user_id"],
            activity_id=sharing_data.activity_id,
            session_token=session_token,
            contacts=json.dumps(sharing_data.contacts),
            expires_at=expires_at,
            created_at=datetime.utcnow(),
            is_active=True
        )
        
        db.add(db_sharing_session)
        db.commit()
        db.refresh(db_sharing_session)
        
        # Get the base URL
        ##base_url = os.getenv("API_BASE_URL", "https://2b00-2c0f-fe38-219b-d073-f583-7cfc-f676-cc1.ngrok-free.app")
        base_url = "https://f7ad1c0e179a.ngrok-free.app"
        
        # Create URLs
        full_tracking_url = f"{base_url}/gps/track/{current_user['user_id']}?session_token={session_token}"
        short_token = session_token[:12]
        short_url = f"{base_url}/track/{short_token}"
        sharing_page_url = f"{base_url}/gps/share/{db_sharing_session.id}/page"
        
        # Get user name
        user_name = current_user.get("name", current_user.get("username", "Someone"))
        
        return {
            "message": "Location sharing started successfully",
            "session_id": db_sharing_session.id,
            "session_token": session_token,
            "tracking_url": full_tracking_url,
            "short_url": short_url,
            "sharing_page_url": sharing_page_url,
            "share_url": full_tracking_url,
            "expires_at": expires_at.isoformat(),
            "expires_readable": expires_at.strftime("%Y-%m-%d at %I:%M %p UTC"),
            "duration_hours": sharing_data.duration_hours,
            "contacts": sharing_data.contacts,
            "contacts_count": len(sharing_data.contacts),
            "sharing_content": {
                "sms_message": f"Track my location: {short_url} (expires {expires_at.strftime('%m/%d at %I:%M %p')})",
                "whatsapp_message": f"Hi! {user_name} is sharing their location with you. Track here: {short_url}",
                "email_subject": f"Location sharing from {user_name}",
                "email_body": f"Hi!\\n\\n{user_name} is sharing their location with you.\\n\\nTrack here: {full_tracking_url}\\n\\nThis link expires on {expires_at.strftime('%Y-%m-%d at %I:%M %p UTC')}",
                "emergency_message": f"🚨 EMERGENCY: {user_name} is sharing their location for safety. Track here: {short_url}"
            },
            "quick_share": {
                "whatsapp": f"https://wa.me/?text={f'Hi! {user_name} is sharing their location. Track here: {short_url}'.replace(' ', '%20')}",
                "telegram": f"https://t.me/share/url?url={short_url}&text={user_name}%20location%20sharing",
                "copy_link": short_url
            },
            "instructions": {
                "test_tracking": f"Click this link to test: {full_tracking_url}",
                "share_page": f"Visit sharing page: {sharing_page_url}",
                "short_link": f"Use this for SMS: {short_url}"
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to start location sharing: {str(e)}")


# Fixed API endpoint for location data
@app.get("/api/gps/location/{user_id}/latest")
async def get_latest_location(
    user_id: str,
    session_token: str,
    db: Session = Depends(get_db)
):
    """Get the latest location data for a user (for AJAX updates)"""
    try:
        # Verify session token
        sharing_session = db.query(LocationSharingSession).filter(
            LocationSharingSession.user_id == user_id,
            LocationSharingSession.session_token == session_token,
            LocationSharingSession.is_active == True,
            LocationSharingSession.expires_at > datetime.utcnow()
        ).first()
        
        if not sharing_session:
            raise HTTPException(status_code=404, detail="Invalid or expired session")
        
        # Get latest location - Fixed the column name issue
        latest_location = db.query(RealTimeGPSLog).filter(
            RealTimeGPSLog.user_id == user_id
        ).order_by(RealTimeGPSLog.recorded_at.desc()).first()
        
        if not latest_location:
            return {"message": "No location data available", "has_data": False}
        
        return {
            "has_data": True,
            "latitude": float(latest_location.latitude),
            "longitude": float(latest_location.longitude),
            "recorded_at": latest_location.recorded_at.isoformat(),
            "accuracy": getattr(latest_location, 'accuracy', None),
            "speed": getattr(latest_location, 'speed', None),
            "heading": getattr(latest_location, 'heading', None)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch location: {str(e)}")


# Add short URL redirect endpoint
@app.get("/track/{short_token}")
async def redirect_to_tracking(
    short_token: str,
    db: Session = Depends(get_db)
):
    """Redirect short token to full tracking URL"""
    try:
        # Find session by matching first 12 characters of token
        sharing_sessions = db.query(LocationSharingSession).filter(
            LocationSharingSession.is_active == True,
            LocationSharingSession.expires_at > datetime.utcnow()
        ).all()
        
        matching_session = None
        for session in sharing_sessions:
            if session.session_token.startswith(short_token):
                matching_session = session
                break
        
        if not matching_session:
            raise HTTPException(status_code=404, detail="Invalid or expired tracking link")
        
        # Redirect to full tracking URL
        return RedirectResponse(
            url=f"/gps/track/{matching_session.user_id}?session_token={matching_session.session_token}",
            status_code=302
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to redirect: {str(e)}")


@app.get("/gps/track/{user_id}")
async def track_user_location(
    user_id: str,
    session_token: str,
    request: Request,
    db: Session = Depends(get_db)
):
    """Display real-time location tracking page for shared sessions"""
    try:
        # Verify the session token
        sharing_session = db.query(LocationSharingSession).filter(
            LocationSharingSession.user_id == user_id,
            LocationSharingSession.session_token == session_token,
            LocationSharingSession.is_active == True,
            LocationSharingSession.expires_at > datetime.utcnow()
        ).first()
        
        if not sharing_session:
            html_content = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Tracking Session Expired</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
                    .error-container { background: white; padding: 30px; border-radius: 10px; max-width: 400px; margin: 0 auto; }
                </style>
            </head>
            <body>
                <div class="error-container">
                    <h2>Tracking Session Not Available</h2>
                    <p>This tracking session has either expired or is invalid.</p>
                    <p>Please request a new tracking link from the person sharing their location.</p>
                </div>
            </body>
            </html>
            """
            return HTMLResponse(content=html_content, status_code=404)
        
        # Get user info
        user = db.query(User).filter(User.id == user_id).first()
        user_name = user.full_name if user and user.full_name else "Unknown User"
        
        # Get latest location
        latest_location = db.query(RealTimeGPSLog).filter(
            RealTimeGPSLog.user_id == user_id
        ).order_by(RealTimeGPSLog.recorded_at.desc()).first()
        
        # Get activity name
        activity_name = "Unknown Activity"
        if sharing_session.activity_id:
            activity = db.query(Activity).filter(Activity.id == sharing_session.activity_id).first()
            if activity:
                activity_name = activity.name
        
        # Replace with your actual Mapbox access token (get from https://mapbox.com)
        MAPBOX_ACCESS_TOKEN = os.getenv("MAPBOX_WEB_TOKEN", "pk.eyJ1Ijoiam95a2lwa2VtYm9pIiwiYSI6ImNtY2J2MmlpZTAxbWIya3NhaWV1aTh5MTkifQ.-nLBrGjd639RrXjdXHq3HA")
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Tracking {user_name}</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src='https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js'></script>
            <link href='https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css' rel='stylesheet' />
            <style>
                body {{ 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; 
                    margin: 0; 
                    padding: 0; 
                    background: #f8f9fa; 
                }}
                .header {{ 
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                    color: white; 
                    padding: 20px; 
                    text-align: center; 
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }}
                .header h2 {{ margin: 0; font-size: 24px; }}
                .header p {{ margin: 5px 0 0 0; opacity: 0.9; }}
                .info-panel {{ 
                    background: white; 
                    padding: 20px; 
                    margin: 15px; 
                    border-radius: 12px; 
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1); 
                }}
                .status {{ 
                    padding: 15px; 
                    border-radius: 8px; 
                    margin: 15px 0; 
                    text-align: center; 
                    font-weight: 500;
                }}
                .active {{ background: #d1edff; color: #0066cc; border: 1px solid #0066cc; }}
                .waiting {{ background: #fff3cd; color: #856404; border: 1px solid #ffc107; }}
                .error {{ background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }}
                #map {{ 
                    height: 600px !important; 
                    width: 100% !important; 
                    margin: 0 auto !important;  
                    border-radius: 12px; 
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }}
                .btn {{ 
                    background: #007bff; 
                    color: white; 
                    padding: 12px 20px; 
                    border: none; 
                    border-radius: 8px; 
                    cursor: pointer; 
                    margin: 5px; 
                    font-size: 14px;
                    font-weight: 500;
                    transition: background 0.2s;
                }}
                .btn:hover {{ background: #0056b3; }}
                .btn-success {{ background: #28a745; }}
                .btn-success:hover {{ background: #1e7e34; }}
                .btn-danger {{ background: #dc3545; }}
                .btn-danger:hover {{ background: #c82333; }}
                .location-info {{ 
                    font-size: 14px; 
                    color: #666; 
                    margin: 10px 0; 
                    background: #f8f9fa;
                    padding: 15px;
                    border-radius: 8px;
                }}
                .activity-badge {{
                    background: #17a2b8;
                    color: white;
                    padding: 6px 12px;
                    border-radius: 15px;
                    font-size: 12px;
                    display: inline-block;
                    margin-top: 5px;
                }}
                .controls {{
                    text-align: center;
                    margin: 20px 0;
                }}
                .loading {{
                    display: inline-block;
                    width: 20px;
                    height: 20px;
                    border: 3px solid #f3f3f3;
                    border-top: 3px solid #3498db;
                    border-radius: 50%;
                    animation: spin 1s linear infinite;
                }}
                @keyframes spin {{
                    0% {{ transform: rotate(0deg); }}
                    100% {{ transform: rotate(360deg); }}
                }}
                .mapboxgl-popup {{
                    max-width: 300px;
                }}
                .mapboxgl-popup-content {{
                    padding: 15px;
                    border-radius: 8px;
                }}
            </style>
        </head>
        <body>
            <div class="header">
                <h2> Tracking {user_name}</h2>
                <p>Real-time Location Sharing</p>
                <span class="activity-badge">{activity_name}</span>
            </div>
            
            <div class="info-panel">
                <div id="status-info">
                    <div class="status {'active' if latest_location else 'waiting'}">
                        <strong>Status:</strong> {'Location Active' if latest_location else ' Waiting for location data...'}
                    </div>
                    {f'''
                    <div class="location-info">
                        <p><strong> Last Update:</strong> {latest_location.recorded_at.strftime("%Y-%m-%d %I:%M:%S %p UTC")}</p>
                        <p><strong> Coordinates:</strong> {latest_location.latitude}, {latest_location.longitude}</p>
                        <p><strong> Activity:</strong> {activity_name}</p>
                        {f'<p><strong> Speed:</strong> {latest_location.speed} km/h</p>' if hasattr(latest_location, 'speed') and latest_location.speed else ''}
                    </div>
                    ''' if latest_location else '<div class="location-info"><p><strong> Status:</strong> No location data received yet</p><p>Waiting for ' + user_name + ' to start sharing location...</p></div>'}
                </div>
                
                <div class="controls">
                    <button class="btn btn-success" onclick="refreshLocation()">
                        <span id="refresh-icon"></span> Refresh Now
                    </button>
                    <button class="btn" onclick="toggleAutoRefresh()" id="autoRefreshBtn">
                         Start Auto-Refresh
                    </button>
                    <button class="btn" onclick="centerMap()"> Center Map</button>
                </div>
            </div>
            
            <div id="map"></div>
            
            <div class="info-panel">
                <p><strong> Session expires:</strong> {sharing_session.expires_at.strftime("%Y-%m-%d at %I:%M %p UTC")}</p>
                <p><strong> Activity:</strong> {activity_name}</p>
                <p><em>This tracking session is temporary and will expire automatically.</em></p>
                <div style="margin-top: 15px; padding: 15px; background: #e9ecef; border-radius: 8px; font-size: 14px;">
                    <strong> How it works:</strong> This page shows the real-time location of {user_name}. 
                    The map updates automatically when new location data is received. 
                    Use the refresh button to check for updates manually.
                </div>
            </div>
            
            <script>
                // Mapbox configuration
                mapboxgl.accessToken = '{MAPBOX_ACCESS_TOKEN}';
                let map;
                let marker;
                let autoRefreshInterval;
                let isAutoRefreshing = false;
                let lastKnownPosition = null;
                let popup;
                
                // Initialize the map
                function initMap() {{
                    // Default location
                    const defaultLat = {latest_location.latitude if latest_location else 0};
                    const defaultLng = {latest_location.longitude if latest_location else 0};
                    const hasData = {str(latest_location is not None).lower()};
                    
                    map = new mapboxgl.Map({{
                        container: 'map',
                        style: 'mapbox://styles/mapbox/dark-v11', // Dark theme with good visibility
                        center: [defaultLng, defaultLat],
                        zoom: hasData ? 16 : 10,            // Zoom in closer
                        pitch: 60,            // Tilt more for 3D view
                        bearing: -20 
                    }});
                    
                    // Add navigation controls
                    map.addControl(new mapboxgl.NavigationControl());
                    
                    // Add geolocate control (optional - lets users see their own location)
                    map.addControl(new mapboxgl.GeolocateControl({{
                        positionOptions: {{
                            enableHighAccuracy: true
                        }},
                        trackUserLocation: false,
                        showUserHeading: false
                    }}));
                    
                    if (hasData) {{
                        lastKnownPosition = [defaultLng, defaultLat];
                        addMarker(lastKnownPosition);
                    }}
                    
                    // Handle map load
                    map.on('load', function() {{
                        console.log('Map loaded successfully');
                        // Add a custom source for the user's location
                        map.addSource('user-location', {{
                            'type': 'geojson',
                            'data': {{
                                'type': 'FeatureCollection',
                                'features': []
                            }}
                        }});
                        map.addLayer({{
                            'id': 'user-location-accuracy',
                            'type': 'circle',
                            'source': 'user-location',
                            'paint': {{
                                'circle-radius': {{
                                    'base': 1.75,
                                    'stops': [[12, 2], [22, 180]]
                                }},
                                'circle-color': '#87ceeb',
                                'circle-opacity': 0.1,
                                'circle-stroke-width': 2,
                                'circle-stroke-color': '#87ceeb',
                                'circle-stroke-opacity': 0.3
                            }}
                        }});
                        
                        // Add a layer for the user's location
                        map.addLayer({{
                            'id': 'user-location-point',
                            'type': 'circle',
                            'source': 'user-location',
                            'paint': {{
                                'circle-radius': 8,
                                'circle-color': '#FF4444',
                                'circle-stroke-width': 3,
                                'circle-stroke-color': '#FFFFFF'
                            }}
                        }});
                        
                        // Add pulsing effect
                        map.addLayer({{
                            'id': 'user-location-pulse',
                            'type': 'circle',
                            'source': 'user-location',
                            'paint': {{
                                'circle-radius': 20,
                                'circle-color': '#FF4444',
                                'circle-opacity': 0.3,
                                'circle-stroke-width': 0
                            }}
                        }});
                        map.addLayer({{
                            'id': '3d-buildings',
                            'source': 'composite',
                            'source-layer': 'building',
                            'filter': ['==', 'extrude', 'true'],
                            'type': 'fill-extrusion',
                            'minzoom': 15,
                            'paint': {{
                                'fill-extrusion-color': '#87ceeb',
                                'fill-extrusion-height': [
                                    'interpolate',
                                    ['linear'],
                                    ['zoom'],
                                    15, 0,
                                    15.05, ['get', 'height']
                                ],
                                'fill-extrusion-base': [
                                    'interpolate',
                                    ['linear'],
                                    ['zoom'],
                                    15, 0,
                                    15.05, ['get', 'min_height']
                                ],
                                'fill-extrusion-opacity': 0.8
                            }}
                        }});
                        
                        
                        // Update marker if we have initial data
                         if (hasData) {{
                            updateMapMarker(defaultLng, defaultLat);
                            // Get location name
                            getLocationName(defaultLng, defaultLat);
                        }}
                        
                    }});
                    map.on('click', function(e) {{
                        console.log('Clicked at:', e.lngLat);
                    }});
                }}
                
                // Add or update marker using Mapbox GL JS
                function addMarker(position) {{
                    if (marker) {{
                        marker.setLngLat(position);
                    }} else {{
                        // Create custom marker element
                        const el = document.createElement('div');
                        el.className = 'custom-marker';
                        el.style.cssText = `
                            width: 30px;
                            height: 30px;
                            border-radius: 50%;
                            background: #FF4444;
                            border: 3px solid white;
                            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
                            cursor: pointer;
                            position: relative;
                        `;
                        
                        // Add pulsing effect
                        el.innerHTML = `
                            <div style="
                                position: absolute;
                                width: 100%;
                                height: 100%;
                                border-radius: 50%;
                                background: #FF4444;
                                opacity: 0.6;
                                animation: pulse 2s infinite;
                            "></div>
                        `;
                        
                        // Add CSS animation
                        if (!document.getElementById('marker-styles')) {{
                            const style = document.createElement('style');
                            style.id = 'marker-styles';
                            style.textContent = `
                                @keyframes pulse {{
                                    0% {{ transform: scale(1); opacity: 0.6; }}
                                    50% {{ transform: scale(1.5); opacity: 0.3; }}
                                    100% {{ transform: scale(2); opacity: 0; }}
                                }}
                            `;
                            document.head.appendChild(style);
                        }}
                        
                        marker = new mapboxgl.Marker(el)
                            .setLngLat(position)
                            .addTo(map);
                        
                        // Create popup
                        popup = new mapboxgl.Popup({{
                            offset: 25,
                            closeButton: true,
                            closeOnClick: false
                        }});
                        
                        // Add click event to marker
                        el.addEventListener('click', function() {{
                            const content = `
                                <div style="padding: 10px; min-width: 200px;">
                                    <h3 style="margin: 0 0 10px 0; color: #333;">{user_name}</h3>
                                    <p style="margin: 5px 0; font-size: 14px;"><strong>Activity:</strong> {activity_name}</p>
                                    <p style="margin: 5px 0; font-size: 12px; color: #666;" id="popup-time">Last updated: Loading...</p>
                                    <p style="margin: 5px 0; font-size: 12px; color: #666;" id="popup-coords">Coordinates: Loading...</p>
                                </div>
                            `;
                            popup.setLngLat(position)
                                .setHTML(content)
                                .addTo(map);
                            
                            // Update popup with current data
                            updatePopupContent();
                        }});
                    }}
                }}
                
                // Update marker using GeoJSON source
                function updateMapMarker(lng, lat) {{
                    if (map.getSource('user-location')) {{
                        map.getSource('user-location').setData({{
                            'type': 'FeatureCollection',
                            'features': [{{
                                'type': 'Feature',
                                'geometry': {{
                                    'type': 'Point',
                                    'coordinates': [lng, lat]
                                }},
                                'properties': {{
                                    'name': '{user_name}',
                                    'activity': '{activity_name}'
                                }}
                            }}]
                        }});
                    }}
                }}
                
                // Center map on current location
                function centerMap() {{
                    if (lastKnownPosition) {{
                        map.flyTo({{
                            center: lastKnownPosition,
                            zoom: 15,
                            duration: 2000
                        }});
                    }} else {{
                        showError('No location data available to center on');
                    }}
                }}
                
                // Refresh location data
                async function refreshLocation() {{
                    console.log('Refreshing location...');
                    const refreshIcon = document.getElementById('refresh-icon');
                    refreshIcon.innerHTML = '<div class="loading"></div>';
                    
                    try {{
                        const response = await fetch(`/api/gps/location/{user_id}/latest?session_token={session_token}`);
                        if (response.ok) {{
                            const data = await response.json();
                            console.log('Location data received:', data);
                            updateMapAndInfo(data);
                        }} else {{
                            console.error('Failed to fetch location data:', response.status);
                            const errorData = await response.json();
                            console.error('Error details:', errorData);
                            showError(`Failed to fetch location: ${{errorData.detail || 'Unknown error'}}`);
                        }}
                    }} catch (error) {{
                        console.error('Error refreshing location:', error);
                        showError('Network error while refreshing location');
                    }} finally {{
                        refreshIcon.innerHTML = '';
                    }}
                }}
                
                // Update map with new location data
                function updateMapAndInfo(locationData) {{
                    console.log('Updating map with:', locationData);
                    
                    if (locationData.has_data && locationData.latitude && locationData.longitude) {{
                        const newPos = [locationData.longitude, locationData.latitude];
                        lastKnownPosition = newPos;
                        
                        // Update marker
                        addMarker(newPos);
                        updateMapMarker(locationData.longitude, locationData.latitude);
                        
                        // Update info panel
                        const statusDiv = document.getElementById('status-info');
                        const updateTime = new Date(locationData.recorded_at).toLocaleString();
                        statusDiv.innerHTML = `
                            <div class="status active">
                                <strong>Status:</strong>  Location Active
                            </div>
                            <div class="location-info">
                                <p><strong> Last Update:</strong> ${{updateTime}}</p>
                                <p><strong> Coordinates:</strong> ${{locationData.latitude.toFixed(6)}}, ${{locationData.longitude.toFixed(6)}}</p>
                                <p><strong> Activity:</strong> {activity_name}</p>
                                ${{locationData.speed ? `<p><strong> Speed:</strong> ${{locationData.speed}} km/h</p>` : ''}}
                                ${{locationData.accuracy ? `<p><strong> Accuracy:</strong> ±${{locationData.accuracy}}m</p>` : ''}}
                            </div>
                        `;
                        
                        // Update popup if it's open
                        updatePopupContent();
                        
                        // Auto-center map on first location update
                        if (!map.getZoom() || map.getZoom() < 10) {{
                            centerMap();
                        }}
                    }} else {{
                        // No data available
                        const statusDiv = document.getElementById('status-info');
                        statusDiv.innerHTML = `
                            <div class="status waiting">
                                <strong>Status:</strong>  Waiting for location data...
                            </div>
                            <div class="location-info">
                                <p><strong> Status:</strong> No location data received yet</p>
                                <p>Waiting for {user_name} to start sharing location...</p>
                            </div>
                        `;
                    }}
                }}
                
                // Update popup content
                function updatePopupContent() {{
                    const timeElement = document.getElementById('popup-time');
                    const coordsElement = document.getElementById('popup-coords');
                    
                    if (timeElement && lastKnownPosition) {{
                        timeElement.textContent = `Last updated: ${{new Date().toLocaleString()}}`;
                    }}
                    if (coordsElement && lastKnownPosition) {{
                        coordsElement.textContent = `Coordinates: ${{lastKnownPosition[1].toFixed(6)}}, ${{lastKnownPosition[0].toFixed(6)}}`;
                    }}
                }}
                
                // Toggle auto-refresh
                function toggleAutoRefresh() {{
                    const btn = document.getElementById('autoRefreshBtn');
                    if (isAutoRefreshing) {{
                        clearInterval(autoRefreshInterval);
                        btn.textContent = 'Start Auto-Refresh';
                        btn.className = 'btn';
                        isAutoRefreshing = false;
                    }} else {{
                        autoRefreshInterval = setInterval(refreshLocation, 15000); // Refresh every 15 seconds
                        btn.textContent = ' Stop Auto-Refresh';
                        btn.className = 'btn btn-danger';
                        isAutoRefreshing = true;
                        
                        // Immediate refresh when starting
                        refreshLocation();
                    }}
                }}
                
                // Show error message
                function showError(message) {{
                    const statusDiv = document.getElementById('status-info');
                    const errorDiv = document.createElement('div');
                    errorDiv.className = 'status error';
                    errorDiv.innerHTML = `<strong>Error:</strong> ${{message}}`;
                    statusDiv.appendChild(errorDiv);
                    
                    // Remove error after 5 seconds
                    setTimeout(() => {{
                        if (errorDiv.parentNode) {{
                            errorDiv.parentNode.removeChild(errorDiv);
                        }}
                    }}, 5000);
                }}
                
                // Initialize map when page loads
                window.onload = function() {{
                    initMap();
                    
                    // Start auto-refresh by default if there's no data yet
                    {f'setTimeout(() => toggleAutoRefresh(), 1000);' if not latest_location else ''}
                }};
                
                // Clean up interval when page unloads
                window.onbeforeunload = function() {{
                    if (autoRefreshInterval) {{
                        clearInterval(autoRefreshInterval);
                    }}
                }};
            </script>
        </body>
        </html>
        """
        
        return HTMLResponse(content=html_content)
        
    except Exception as e:
        logger.error(f"Error in track_user_location: {{str(e)}}")
        raise HTTPException(status_code=500, detail=f"Failed to load tracking page: {{str(e)}}")

# API endpoint to get latest location data (called by the tracking page)
@app.get("/api/gps/location/{user_id}/latest")
async def get_latest_gps_location(
    user_id: str,
    session_token: str,
    db: Session = Depends(get_db)
):
    """Get the latest GPS location data for a user (for AJAX updates)"""
    try:
        # Verify session token
        sharing_session = db.query(LocationSharingSession).filter(
            LocationSharingSession.user_id == user_id,
            LocationSharingSession.session_token == session_token,
            LocationSharingSession.is_active == True,
            LocationSharingSession.expires_at > datetime.utcnow()
        ).first()
        
        if not sharing_session:
            raise HTTPException(status_code=404, detail="Invalid or expired session")
        
        # Get latest location from RealTimeGPSLog
        latest_location = db.query(RealTimeGPSLog).filter(
            RealTimeGPSLog.user_id == user_id
        ).order_by(RealTimeGPSLog.recorded_at.desc()).first()
        
        if not latest_location:
            return {
                "message": "No location data available", 
                "has_data": False,
                "user_id": user_id,
                "session_active": True
            }
        
        # Get activity info
        activity_name = "Unknown Activity"
        if latest_location.activity_id:
            activity = db.query(Activity).filter(Activity.id == latest_location.activity_id).first()
            if activity:
                activity_name = activity.name
        
        return {
            "has_data": True,
            "user_id": user_id,
            "latitude": latest_location.latitude,
            "longitude": latest_location.longitude,
            "recorded_at": latest_location.recorded_at.isoformat(),
            "activity_id": latest_location.activity_id,
            "activity_name": activity_name,
            "session_active": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_latest_gps_location: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch location: {str(e)}")


# Optional: Add an endpoint to get location history/trail
@app.get("/api/gps/location/{user_id}/trail")
async def get_location_trail(
    user_id: str,
    session_token: str,
    hours: int = 1,  # Get trail for last N hours
    db: Session = Depends(get_db)
):
    """Get location trail/history for mapping a path"""
    try:
        # Verify session token
        sharing_session = db.query(LocationSharingSession).filter(
            LocationSharingSession.user_id == user_id,
            LocationSharingSession.session_token == session_token,
            LocationSharingSession.is_active == True,
            LocationSharingSession.expires_at > datetime.utcnow()
        ).first()
        
        if not sharing_session:
            raise HTTPException(status_code=404, detail="Invalid or expired session")
        
        # Get location history
        since_time = datetime.utcnow() - timedelta(hours=hours)
        location_trail = db.query(RealTimeGPSLog).filter(
            RealTimeGPSLog.user_id == user_id,
            RealTimeGPSLog.recorded_at >= since_time
        ).order_by(RealTimeGPSLog.recorded_at.asc()).all()
        
        trail_data = [
            {
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "recorded_at": loc.recorded_at.isoformat(),
                "activity_id": loc.activity_id
            }
            for loc in location_trail
        ]
        
        return {
            "user_id": user_id,
            "trail_points": len(trail_data),
            "hours_span": hours,
            "trail": trail_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_location_trail: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch location trail: {str(e)}")

# Keep your existing helper endpoints
@app.get("/gps/share/{session_id}/link", response_model=dict)
async def get_shareable_link(
    session_id: int,
    message_type: str = "default",  # default, emergency, casual, custom
    custom_message: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get a formatted shareable link with custom message"""
    try:
        # Get the sharing session
        sharing_session = db.query(LocationSharingSession).filter(
            LocationSharingSession.id == session_id,
            LocationSharingSession.user_id == current_user["user_id"],
            LocationSharingSession.is_active == True,
            LocationSharingSession.expires_at > datetime.utcnow()
        ).first()
        
        if not sharing_session:
            raise HTTPException(status_code=404, detail="Active sharing session not found")
        
        # Get user name for personalized messages
        user_name = current_user.get("name", current_user.get("username", "Someone"))
        
        # Create URLs
        short_token = sharing_session.session_token[:12]
        ##base_url = os.getenv("API_BASE_URL", "https://2b00-2c0f-fe38-219b-d073-f583-7cfc-f676-cc1.ngrok-free.app")  # Replace with your actual domain
        base_url="https://f7ad1c0e179a.ngrok-free.app"
        short_url = f"{base_url}/track/{short_token}"
        full_url = f"{base_url}/gps/track/{sharing_session.user_id}?session_token={sharing_session.session_token}"
        
        # Expiration info
        expires_at = sharing_session.expires_at
        expires_str = expires_at.strftime("%m/%d at %I:%M %p")
        
        # Message templates
        messages = {
            "default": f"Hi! {user_name} is sharing their live location with you. Track here: {short_url} (expires {expires_str})",
            "emergency": f" EMERGENCY: {user_name} is sharing their location for safety. Track here: {short_url} (expires {expires_str})",
            "casual": f"Hey! Following my location? Here's the link: {short_url} (expires {expires_str}) - {user_name}",
            "professional": f"Location sharing from {user_name}. Access tracking here: {short_url} (Valid until {expires_str})",
            "custom": custom_message or f"Track my location: {short_url}"
        }
        
        selected_message = messages.get(message_type, messages["default"])
        
        return {
            "session_id": session_id,
            "short_url": short_url,
            "full_url": full_url,
            "message": selected_message,
            "expires_at": expires_at.isoformat(),
            "expires_readable": expires_str,
            "sharing_options": {
                "whatsapp": f"https://wa.me/?text={selected_message.replace(' ', '%20')}",
                "telegram": f"https://t.me/share/url?url={short_url}&text={user_name}%20is%20sharing%20location",
                "email_subject": f"Location sharing from {user_name}",
                "email_body": selected_message,
                "copy_paste": selected_message
            },
            "available_message_types": list(messages.keys())
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate shareable link: {str(e)}")


# Activity management endpoints
@app.post("/activities", response_model=ActivityShow)
async def create_activity(
    activity_data: ActivityCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Create a new activity"""
    try:
        db_activity = Activity(
            user_id=current_user["user_id"],
            name=activity_data.name,
            description=activity_data.description,
            created_at=datetime.utcnow(),
            is_active=True
        )
        
        db.add(db_activity)
        db.commit()
        db.refresh(db_activity)
        
        return db_activity
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create activity: {str(e)}")

@app.get("/activities", response_model=List[ActivityShow])
async def get_user_activities(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get all activities for the current user"""
    try:
        activities = db.query(Activity).filter(
            Activity.user_id == current_user["user_id"]
        ).order_by(Activity.created_at.desc()).all()
        
        return activities
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch activities: {str(e)}")

async def broadcast_location_update(user_id: UUID, location_data: dict):
    """Broadcast location update to all active connections for a user"""
    user_id_str = str(user_id)
    if user_id_str in active_connections:
        # In a real implementation with WebSockets, you'd broadcast to all connections
        # For SSE, you might use a message queue or pub/sub system
        print(f"Broadcasting location update for user {user_id}: {location_data}")

        
# Police Location Endpoints - CORRECTED
@app.get("/police-locations", response_model=List[PoliceLocationResponse])
async def get_police_locations(db: Session = Depends(get_db)):
    """Get all police locations"""
    locations = db.query(PoliceLocation).all()  # SQLAlchemy model for DB query
    return locations

@app.get("/police-locations/{location_id}", response_model=PoliceLocationResponse)
async def get_police_location(location_id: int, db: Session = Depends(get_db)):
    """Get a specific police location by ID"""
    location = db.query(PoliceLocation).filter(PoliceLocation.id == location_id).first()
    if not location:
        raise HTTPException(status_code=404, detail="Police location not found")
    return location

@app.post("/police-locations", response_model=PoliceLocationResponse)
async def create_police_location(location: PoliceLocationCreate, db: Session = Depends(get_db)):
    """Create a new police location"""
    db_location = PoliceLocation(**location.dict())  # SQLAlchemy model for DB
    db.add(db_location)
    db.commit()
    db.refresh(db_location)
    return db_location

@app.put("/police-locations/{location_id}", response_model=PoliceLocationResponse)
async def update_police_location(
    location_id: int, 
    location: PoliceLocationUpdate,  # Use PoliceLocationUpdate for PUT requests
    db: Session = Depends(get_db)
):
    """Update a police location"""
    db_location = db.query(PoliceLocation).filter(PoliceLocation.id == location_id).first()
    if not db_location:
        raise HTTPException(status_code=404, detail="Police location not found")
    
    # Update the SQLAlchemy model with Pydantic data
    for key, value in location.dict().items():
        setattr(db_location, key, value)
    
    db.commit()
    db.refresh(db_location)
    return db_location

@app.delete("/police-locations/{location_id}")
async def delete_police_location(location_id: int, db: Session = Depends(get_db)):
    """Delete a police location"""
    db_location = db.query(PoliceLocation).filter(PoliceLocation.id == location_id).first()
    if not db_location:
        raise HTTPException(status_code=404, detail="Police location not found")
    
    db.delete(db_location)
    db.commit()
    return {"message": "Police location deleted successfully"}

# Danger Zone Endpoints - CORRECTED
@app.get("/danger-zones", response_model=List[DangerZoneResponse])
async def get_danger_zones(
    active_only: bool = True,
    db: Session = Depends(get_db)
):
    """Get all danger zones"""
    query = db.query(DangerZone)  # SQLAlchemy model for DB query

    zones = query.all()
    return zones

@app.get("/danger-zones/{zone_id}", response_model=DangerZoneResponse)
async def get_danger_zone(zone_id: int, db: Session = Depends(get_db)):
    """Get a specific danger zone by ID"""
    zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Danger zone not found")
    return zone

@app.post("/danger-zones", response_model=DangerZoneResponse)
async def create_danger_zone(zone: DangerZoneCreate, db: Session = Depends(get_db)):
    """Create a new danger zone"""
    db_zone = DangerZone(**zone.dict())  # SQLAlchemy model for DB
    db.add(db_zone)
    db.commit()
    db.refresh(db_zone)
    return db_zone

@app.put("/danger-zones/{zone_id}", response_model=DangerZoneResponse)
async def update_danger_zone(
    zone_id: int, 
    zone: DangerZoneCreate,  # Use Pydantic model for request body
    db: Session = Depends(get_db)
):
    """Update a danger zone"""
    db_zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not db_zone:
        raise HTTPException(status_code=404, detail="Danger zone not found")
    
    for key, value in zone.dict().items():
        setattr(db_zone, key, value)
    
    db.commit()
    db.refresh(db_zone)
    return db_zone

@app.delete("/danger-zones/{zone_id}")
async def delete_danger_zone(zone_id: int, db: Session = Depends(get_db)):
    """Delete a danger zone"""
    db_zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not db_zone:
        raise HTTPException(status_code=404, detail="Danger zone not found")
    
    db.delete(db_zone)
    db.commit()
    return {"message": "Danger zone deleted successfully"}

# Proximity-based endpoints - CORRECTED
@app.post("/proximity-check", response_model=ProximityResponse)
async def check_proximity(alert: ProximityAlert, db: Session = Depends(get_db)):
    """Check for nearby police stations and danger zones"""
    
    # Get all active locations - Use SQLAlchemy models for DB queries
    police_locations = db.query(PoliceLocation).all()  # Changed from PoliceLocationBase
    danger_zones = db.query(DangerZone).filter(DangerZone.is_active == 1).all()
    
    nearby_police = []
    nearby_dangers = []
    warnings = []
    
    # Check proximity to police stations
    for location in police_locations:
        distance = calculate_distance(
            alert.user_latitude, alert.user_longitude,
            location.latitude, location.longitude
        )
        
        if distance <= alert.radius:
            nearby_police.append(location)
    
    # Check proximity to danger zones
    for zone in danger_zones:
        distance = calculate_distance(
            alert.user_latitude, alert.user_longitude,
            zone.latitude, zone.longitude
        )
        
        if distance <= zone.radius:
            nearby_dangers.append(zone)
            # Generate warning based on severity
            if zone.severity_level >= 4:
                warnings.append(f"HIGH RISK: You are near {zone.location_name}. {zone.description}")
            elif zone.severity_level >= 2:
                warnings.append(f"CAUTION: You are approaching {zone.location_name}. {zone.description}")
            else:
                warnings.append(f"NOTICE: You are near {zone.location_name}")
    
    return ProximityResponse(
        nearby_police=nearby_police,
        nearby_dangers=nearby_dangers,
        warnings=warnings
    )

@app.get("/nearby-police")
async def get_nearby_police(
    latitude: float,
    longitude: float,
    radius: float = 5000.0,  # 5km default
    db: Session = Depends(get_db)
):
    """Get police stations within specified radius"""
    locations = db.query(PoliceLocation).all()  # Changed from PoliceLocationBase
    nearby = []
    
    for location in locations:
        distance = calculate_distance(latitude, longitude, location.latitude, location.longitude)
        if distance <= radius:
            location_dict = {
                "id": location.id,
                "name": location.name,
                "latitude": float(location.latitude),  # Convert Decimal to float
                "longitude": float(location.longitude),  # Convert Decimal to float
                "contact_number": location.contact_number,
                # Note: Removed address and station_type as they're not in your PoliceLocation model
                "distance": round(distance, 2)
            }
            nearby.append(location_dict)
    
    # Sort by distance
    nearby.sort(key=lambda x: x['distance'])
    return {"nearby_police": nearby}

@app.get("/nearby-dangers")
async def get_nearby_dangers(
    latitude: float,
    longitude: float,
    radius: float = 2000.0,  # 2km default
    db: Session = Depends(get_db)
):
    """Get danger zones within specified radius"""
    zones = db.query(DangerZone).filter(DangerZone.is_active == 1).all()
    nearby = []
    
    for zone in zones:
        distance = calculate_distance(latitude, longitude, zone.latitude, zone.longitude)
        if distance <= radius:
            zone_dict = {
                "id": zone.id,
                "location_name": zone.location_name,  # Use correct field name
                "latitude": float(zone.latitude),  # Convert Decimal to float
                "longitude": float(zone.longitude),  # Convert Decimal to float
                "description": zone.description,
                # Note: Removed fields that don't exist in your DangerZone model
                "reported_count": zone.reported_count,
                "distance": round(distance, 2)
            }
            nearby.append(zone_dict)
    
    # Sort by distance
    nearby.sort(key=lambda x: x['distance'])
    return {"nearby_dangers": nearby}

# Statistics endpoint - CORRECTED
@app.get("/stats")
async def get_stats(db: Session = Depends(get_db)):
    """Get system statistics"""
    police_count = db.query(PoliceLocation).count()  # Changed from PoliceLocationBase
    danger_count = db.query(DangerZone).filter(DangerZone.is_active == 1).count()
    total_danger_count = db.query(DangerZone).count()
    
    return {
        "police_locations": police_count,
        "active_danger_zones": danger_count,
        "total_danger_zones": total_danger_count,
        "api_version": "1.0.0"
    }

@app.get("/analytics/user-distribution", response_model=UserDistributionResponse)
async def get_user_distribution(db: Session = Depends(get_db)):
    """Get user distribution analytics"""
    try:
        # Count users by role_id
        total_users = db.query(User).filter(User.role_id == 5).count()
        admins = db.query(User).filter(User.role_id == 4).count()
        
        # Count legal aid providers
        legal_aid_providers = db.query(LegalAidProvider).count()
        
        return UserDistributionResponse(
            total_users=total_users,
            legal_aid_providers=legal_aid_providers,
            admins=admins
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching user distribution: {str(e)}")
@app.get("/analytics/danger-zones", response_model=DangerZonesResponse)
async def get_danger_zones_analytics(db: Session = Depends(get_db)):
    """Get danger zones analytics from the database"""
    try:
        # Query all danger zones from the DB
        danger_zones = db.query(DangerZone).all()

        # Convert DB objects to Pydantic response format
        danger_zones_data = [
            DangerZoneDataPoint(
                location_name=zone.location_name,
                reported_count=zone.reported_count
            ) for zone in danger_zones
        ]

        # Calculate total incidents
        total_incidents = sum(zone.reported_count for zone in danger_zones)

        # Return response
        return DangerZonesResponse(
            data=danger_zones_data,
            total_incidents=total_incidents
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching danger zones data: {str(e)}")
    
@app.get("/analytics/dashboard", response_model=AnalyticsResponse)
async def get_dashboard_analytics(db: Session = Depends(get_db)):
    """Get all analytics data for dashboard"""
    try:
        user_distribution = await get_user_distribution(db)
        
        danger_zones = await get_danger_zones_analytics(db)
        
        return AnalyticsResponse(
            user_distribution=user_distribution,
            danger_zones=danger_zones
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching dashboard analytics: {str(e)}")

@app.get("/legal-aid-providers", response_model=List[ShowLegalAid])
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

@app.get("/legal-aid-providers/{provider_id}", response_model=ShowLegalAid)
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
@app.post("/legal-aid-requests", response_model=ShowLegalAidRequest)
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

from sqlalchemy import func, text
from datetime import datetime, timedelta

@app.get("/analytics/recent-locations")
async def get_recent_locations_analytics_fixed(
    db: Session = Depends(get_db)
):
    """Fixed recent locations analytics - PostgreSQL compatible"""
    # Use the specific user ID for testing
    test_user_id = "98cd414b-f720-419b-98b5-04ececc0b322"
    
    try:
        # First, verify the user exists
        test_user = db.query(User).filter(User.id == test_user_id).first()
        if not test_user:
            return {"error": f"Test user {test_user_id} not found in database"}
        
        print(f"Testing with user: {test_user.email}")
        
        # Get users with recent GPS logs (last 7 days)
        seven_days_ago = datetime.now() - timedelta(days=7)
        
        # Simplified query for users with recent location data
        recent_locations_query = db.query(
            RealTimeGPSLog.user_id,
            func.count(RealTimeGPSLog.id).label('total_logs'),
            func.max(RealTimeGPSLog.recorded_at).label('last_recorded'),
            func.min(RealTimeGPSLog.recorded_at).label('first_recorded')
        ).filter(
            RealTimeGPSLog.recorded_at >= seven_days_ago
        ).group_by(RealTimeGPSLog.user_id).all()
        
        print(f"Found {len(recent_locations_query)} users with recent location data")
        
        # Get total users count
        total_users = db.query(User).count()
        print(f"Total users in database: {total_users}")
        
        # Get users with location sharing enabled
        active_users = len(recent_locations_query)
        inactive_users = total_users - active_users
        
        # Simplified top locations query using raw SQL for PostgreSQL compatibility
        top_locations_raw = db.execute(text("""
            SELECT 
                ROUND(CAST(latitude AS NUMERIC), 3) as lat,
                ROUND(CAST(longitude AS NUMERIC), 3) as lng,
                COUNT(*) as visit_count
            FROM realtime_gps_logs 
            WHERE recorded_at >= :seven_days_ago
            GROUP BY ROUND(CAST(latitude AS NUMERIC), 3), ROUND(CAST(longitude AS NUMERIC), 3)
            ORDER BY COUNT(*) DESC
            LIMIT 10
        """), {"seven_days_ago": seven_days_ago}).fetchall()
        
        print(f"Found {len(top_locations_raw)} top locations")
        
        # Recent user activities
        recent_activities = db.query(
            User.email,
            RealTimeGPSLog.latitude,
            RealTimeGPSLog.longitude,
            RealTimeGPSLog.recorded_at,
            Activity.name.label('activity_name')
        ).join(
            RealTimeGPSLog, User.id == RealTimeGPSLog.user_id
        ).join(
            Activity, RealTimeGPSLog.activity_id == Activity.id
        ).filter(
            RealTimeGPSLog.recorded_at >= seven_days_ago
        ).order_by(
            RealTimeGPSLog.recorded_at.desc()
        ).limit(20).all()
        
        print(f"Found {len(recent_activities)} recent activities")
        
        # Check if our test user has any GPS logs
        test_user_logs = db.query(RealTimeGPSLog).filter(
            RealTimeGPSLog.user_id == test_user_id,
            RealTimeGPSLog.recorded_at >= seven_days_ago
        ).count()
        
        print(f"Test user has {test_user_logs} GPS logs in the last 7 days")
        
        # Calculate unique locations for each user using a separate query
        user_stats_with_unique_locations = []
        for stat in recent_locations_query:
            # Get unique locations for this user
            unique_locations_count = db.execute(text("""
                SELECT COUNT(DISTINCT(
                    ROUND(CAST(latitude AS NUMERIC), 3)::text || ',' || 
                    ROUND(CAST(longitude AS NUMERIC), 3)::text
                ))
                FROM realtime_gps_logs 
                WHERE user_id = :user_id AND recorded_at >= :seven_days_ago
            """), {
                "user_id": stat.user_id, 
                "seven_days_ago": seven_days_ago
            }).scalar()
            
            user_stats_with_unique_locations.append({
                "user_id": str(stat.user_id),
                "total_logs": stat.total_logs,
                "unique_locations": unique_locations_count,
                "last_recorded": stat.last_recorded.isoformat(),
                "first_recorded": stat.first_recorded.isoformat()
            })
        
        return {
            "test_info": {
                "user_id": test_user_id,
                "user_email": test_user.email,
                "user_gps_logs_count": test_user_logs
            },
            "total_users": total_users,
            "active_location_users": active_users,
            "inactive_location_users": inactive_users,
            "location_sharing_rate": round((active_users / total_users * 100), 1) if total_users > 0 else 0,
            "top_locations": [
                {
                    "latitude": float(row.lat),
                    "longitude": float(row.lng),
                    "visit_count": row.visit_count
                }
                for row in top_locations_raw
            ],
            "recent_activities": [
                {
                    "user_email": activity.email,
                    "latitude": activity.latitude,
                    "longitude": activity.longitude,
                    "activity_name": activity.activity_name,
                    "recorded_at": activity.recorded_at.isoformat()
                }
                for activity in recent_activities
            ],
            "user_location_stats": user_stats_with_unique_locations
        }
        
    except Exception as e:
        print(f"Error in fixed endpoint: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error fetching location analytics: {str(e)}")


# Also, here's the corrected version of your original endpoint
@app.get("/analytics/recent-locations-analytics")
async def get_recent_locations_analytics(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get recent locations analytics - accessible to any authenticated user - FIXED"""
    try:
        # Get users with recent GPS logs (last 7 days)
        seven_days_ago = datetime.now() - timedelta(days=7)
        
        # Simplified query for users with recent location data (removed problematic unique_locations)
        recent_locations_query = db.query(
            RealTimeGPSLog.user_id,
            func.count(RealTimeGPSLog.id).label('total_logs'),
            func.max(RealTimeGPSLog.recorded_at).label('last_recorded'),
            func.min(RealTimeGPSLog.recorded_at).label('first_recorded')
        ).filter(
            RealTimeGPSLog.recorded_at >= seven_days_ago
        ).group_by(RealTimeGPSLog.user_id).all()
        
        # Get total users count
        total_users = db.query(User).count()
        
        # Get users with location sharing enabled
        active_users = len(recent_locations_query)
        inactive_users = total_users - active_users
        
        # Get top locations using raw SQL for PostgreSQL compatibility
        top_locations_raw = db.execute(text("""
            SELECT 
                ROUND(CAST(latitude AS NUMERIC), 3) as lat,
                ROUND(CAST(longitude AS NUMERIC), 3) as lng,
                COUNT(*) as visit_count
            FROM realtime_gps_logs 
            WHERE recorded_at >= :seven_days_ago
            GROUP BY ROUND(CAST(latitude AS NUMERIC), 3), ROUND(CAST(longitude AS NUMERIC), 3)
            ORDER BY COUNT(*) DESC
            LIMIT 10
        """), {"seven_days_ago": seven_days_ago}).fetchall()
        
        # Recent user activities
        recent_activities = db.query(
            User.email,
            RealTimeGPSLog.latitude,
            RealTimeGPSLog.longitude,
            RealTimeGPSLog.recorded_at,
            Activity.name.label('activity_name')
        ).join(
            RealTimeGPSLog, User.id == RealTimeGPSLog.user_id
        ).join(
            Activity, RealTimeGPSLog.activity_id == Activity.id
        ).filter(
            RealTimeGPSLog.recorded_at >= seven_days_ago
        ).order_by(
            RealTimeGPSLog.recorded_at.desc()
        ).limit(20).all()
        
        # Calculate unique locations for each user using separate queries
        user_stats_with_unique_locations = []
        for stat in recent_locations_query:
            # Get unique locations for this user
            unique_locations_count = db.execute(text("""
                SELECT COUNT(DISTINCT(
                    ROUND(CAST(latitude AS NUMERIC), 3)::text || ',' || 
                    ROUND(CAST(longitude AS NUMERIC), 3)::text
                ))
                FROM realtime_gps_logs 
                WHERE user_id = :user_id AND recorded_at >= :seven_days_ago
            """), {
                "user_id": stat.user_id, 
                "seven_days_ago": seven_days_ago
            }).scalar()
            
            user_stats_with_unique_locations.append({
                "user_id": str(stat.user_id),
                "total_logs": stat.total_logs,
                "unique_locations": unique_locations_count,
                "last_recorded": stat.last_recorded.isoformat(),
                "first_recorded": stat.first_recorded.isoformat()
            })
        
        return {
            "total_users": total_users,
            "active_location_users": active_users,
            "inactive_location_users": inactive_users,
            "location_sharing_rate": round((active_users / total_users * 100), 1) if total_users > 0 else 0,
            "top_locations": [
                {
                    "latitude": float(row.lat),
                    "longitude": float(row.lng),
                    "visit_count": row.visit_count
                }
                for row in top_locations_raw
            ],
            "recent_activities": [
                {
                    "user_email": activity.email,
                    "latitude": activity.latitude,
                    "longitude": activity.longitude,
                    "activity_name": activity.activity_name,
                    "recorded_at": activity.recorded_at.isoformat()
                }
                for activity in recent_activities
            ],
            "user_location_stats": user_stats_with_unique_locations
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching location analytics: {str(e)}")
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


