import json
import logging
import traceback
import uuid
from sqlalchemy import UUID, func
import authentication, locations
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
app.include_router(locations.router)
##app.include_router(authentication.router)
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 10080))   # 7 days
REFRESH_TOKEN_EXPIRE_MINUTES = int(os.getenv("REFRESH_TOKEN_EXPIRE_MINUTES", 43200))  # 30 days
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
@app.post("/login", response_model=TokenSchema)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    print(f"--- Login Attempt: {form_data.username} ---")
    # User Query
    user = db.query(models.User).filter(
        (func.lower(models.User.email) == form_data.username.strip().lower()) |
        (models.User.phone_number == form_data.username)
    ).first()
    # Legal Aid Query
    legal_aid = db.query(models.LegalAidProvider).filter(
        (func.lower(models.LegalAidProvider.email) == form_data.username.strip().lower()) |
        (models.LegalAidProvider.phone_number == form_data.username)
    ).first()
    authenticated_user = None
    user_type = None
    role_id = None  # Initialize explicitly
    
    if user:
         print(f"User found: {user.id}, Role: {user.role_id}")
         if verify_password(form_data.password, user.password_hash):
            authenticated_user = user
            user_type = "user"
            db.refresh(user)
            role_id = user.role_id
            print(f"USER Authenticated - ID: {user.id}, role_id: {role_id}")
         else:
             print(f"User password mismatch for {user.email}")
    else:
         print(f"User not found for {form_data.username}")
    if legal_aid:
        print(f"Legal Aid found: {legal_aid.id}, Role: {legal_aid.role_id}")
        if verify_password(form_data.password, legal_aid.password_hash):
            authenticated_user = legal_aid
            user_type = "legal_aid"
            db.refresh(legal_aid)
            role_id = legal_aid.role_id
            print(f"LEGAL_AID Authenticated - ID: {legal_aid.id}, role_id: {role_id}")
        else:
             print(f"Legal Aid password mismatch for {legal_aid.id}")
    else:
        print(f"Legal Aid not found for {form_data.username}")
    if not authenticated_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(authenticated_user.id, user_type, role_id)
    refresh_token = create_refresh_token(authenticated_user.id)

    if user_type == "user":
        token_db = UserTokenTable(
            user_id=authenticated_user.id,
            access_token=access_token,
            refresh_token=refresh_token,
            status=True
        )
    elif user_type == "legal_aid":
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
    
@app.get("/view-legal-aid-providers")
def view_legal_aid_providers(db: Session = Depends(get_db)):
    """View all legal aid providers"""
    try:
        legal_aid_providers = db.query(models.LegalAidProvider).all()
        return [ShowLegalAid.from_orm(provider) for provider in legal_aid_providers]
    except Exception as e:
        logger.error(f"Failed to fetch legal aid providers: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to fetch legal aid providers")
    
@app.middleware("http")
async def log_request(request: Request, call_next):
    body = await request.body()
    logging.info(f"Request body: {body.decode('utf-8')}")
    
    response = await call_next(request)
    return response
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)