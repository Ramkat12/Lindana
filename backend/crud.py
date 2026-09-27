import os
import uuid
from pydantic import UUID4
from sqlalchemy import and_
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from datetime import datetime, timedelta
from typing import List, Optional, Union, Any
from jose import jwt
from dotenv import load_dotenv
from schema import LegalAidRequestCreate, LegalTipCreate, LegalTipUpdate, RequestStatus
import models
import schema
from models import ExpertiseArea, LegalAidRequest, LegalTip, TipStatus, User,  LegalAidProvider ,EmergencyContact
from schema import CreateUser, CreateLegalAid
import base64
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from database import get_db

# Load environment variables from .env file
load_dotenv()

# JWT Configuration from environment variables
# Access token: 7 days — users rarely need to re-login
# Refresh token: 30 days — full session window
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 10080))  # 7 days
REFRESH_TOKEN_EXPIRE_MINUTES = int(os.getenv("REFRESH_TOKEN_EXPIRE_MINUTES", 43200))  # 30 days
ALGORITHM = "HS256"
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_REFRESH_SECRET_KEY = os.getenv("JWT_REFRESH_SECRET_KEY")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Ensure secret keys are set
if not JWT_SECRET_KEY or not JWT_REFRESH_SECRET_KEY:
    raise ValueError("JWT_SECRET_KEY and JWT_REFRESH_SECRET_KEY must be set in .env file")

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Create directory for storing profile images
UPLOAD_DIR = "uploads/profile_images"
os.makedirs(UPLOAD_DIR, exist_ok=True)

def save_base64_image(base64_string: str, user_id: int, user_type: str) -> str:
    """
    Save base64 encoded image to file system and return the file path
    """
    try:
        # Remove data:image/jpeg;base64, prefix if present
        if "," in base64_string:
            base64_string = base64_string.split(",")[1]
        
        # Decode base64 string
        image_data = base64.b64decode(base64_string)
        
        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{user_type}_{user_id}_{timestamp}_{uuid.uuid4().hex[:8]}.jpg"
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        # Save image to file
        with open(file_path, "wb") as f:
            f.write(image_data)
        
        # Return relative path that can be used as URL
        return f"/uploads/profile_images/{filename}"
        
    except Exception as e:
        print(f"Error saving image: {e}")
        return None
    
# Fix 1: Update get_current_user function to return consistent keys
def get_token_record(db: Session, user_type: str, access_token: str):
    if user_type == "user":
        return db.query(models.UserTokenTable).filter(
            models.UserTokenTable.access_token == access_token
        ).first()
    elif user_type == "legal_aid":
        return db.query(models.LegalAidTokenTable).filter(
            models.LegalAidTokenTable.access_token == access_token
        ).first()
    return None


def get_token_record_by_refresh(db: Session, user_type: str, refresh_token: str):
    if user_type == "user":
        return db.query(models.UserTokenTable).filter(
            models.UserTokenTable.refresh_token == refresh_token
        ).first()
    elif user_type == "legal_aid":
        return db.query(models.LegalAidTokenTable).filter(
            models.LegalAidTokenTable.refresh_token == refresh_token
        ).first()
    return None


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> dict:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise credentials_exception

        user_id: str = payload.get("sub")
        user_type: str = payload.get("user_type")
        role_id = payload.get("role_id")

        if user_id is None or user_type is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # A token is only valid while its DB record is still marked active —
    # this is what makes /logout actually revoke access instead of just
    # flipping a column nobody reads.
    token_record = get_token_record(db, user_type, token)
    if not token_record or not token_record.status:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return {"user_id": user_id, "user_type": user_type, "role_id": role_id, "token": token}


# Password functions
def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)



def create_access_token(user_id: str, user_type: str, role_id: int):
    payload = {
        "sub": str(user_id),  # Convert UUID to string
        "user_type": user_type,
        "role_id": role_id,
        "type": "access",
        "exp": datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=ALGORITHM)




def create_refresh_token(user_id: str, user_type: str):
    expire = datetime.utcnow() + timedelta(minutes=REFRESH_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "user_type": user_type,
        "type": "refresh",
        "exp": expire
    }
    return jwt.encode(payload, JWT_REFRESH_SECRET_KEY, algorithm=ALGORITHM)

# Database query functions
def get_user_by_phone(db: Session, phone_number: str):
    return db.query(User).filter(User.phone_number == phone_number).first()

def create_user(db: Session, user: CreateUser):
    hashed_password = get_password_hash(user.password_hash)

    db_user = User(
        full_name=user.full_name,
        phone_number=user.phone_number,
        email=user.email.lower(),
        password_hash=hashed_password,
        role_id=user.role_id,
        profile_image=user.profile_image,
        created_at=datetime.utcnow()
    )

    # Add emergency contact via relationship if provided
    
    ec = EmergencyContact(
        contact_name=user.emergency_contact_name,
        contact_number=user.emergency_contact_number,
        email_contact=user.emergency_contact_email)
    db_user.emergency_contacts.append(ec)

    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    # Save profile image if provided
    if user.profile_image:
        image_path = save_base64_image(user.profile_image, db_user.id, "user")
        if image_path:
            db_user.profile_image = image_path
            db.commit()
            db.refresh(db_user)

    return db_user


def create_legal_aid(db: Session, legal_aid: CreateLegalAid):
    hashed_password = get_password_hash(legal_aid.password_hash)

    # Fetch expertise area objects from the DB
    expertise_objs = db.query(ExpertiseArea).filter(
        ExpertiseArea.id.in_(legal_aid.expertise_area_ids)
    ).all() if legal_aid.expertise_area_ids else []

    db_legal_aid = LegalAidProvider(
        full_name=legal_aid.full_name,
        phone_number=legal_aid.phone_number,
        email=legal_aid.email.lower(),
        password_hash=hashed_password,
        status=legal_aid.status,
        role_id=legal_aid.role_id,
        profile_image=None,  # Will update later if image is provided
        created_at=datetime.utcnow(),
        psk_number=legal_aid.psk_number,
        about=legal_aid.about,
        expertise_areas=expertise_objs
    )

    db.add(db_legal_aid)
    db.commit()
    db.refresh(db_legal_aid)

    # Save profile image if provided
    if legal_aid.profile_image:
        image_path = save_base64_image(legal_aid.profile_image, db_legal_aid.id, "legal_aid")
        if image_path:
            db_legal_aid.profile_image = image_path
            db.commit()
            db.refresh(db_legal_aid)

    return db_legal_aid
class LegalTipCRUD:
    
    @staticmethod
    def create_tip(db: Session, tip_data: LegalTipCreate) -> LegalTip:
        db_tip = LegalTip(**tip_data.dict())
        db.add(db_tip)
        db.commit()
        db.refresh(db_tip)
        return db_tip
    
    @staticmethod
    def get_tip_by_id(db: Session, tip_id: UUID4) -> Optional[LegalTip]:
        return db.query(LegalTip).filter(LegalTip.id == tip_id).first()
    
    @staticmethod
    def get_tips_by_provider(db: Session, provider_id: UUID4) -> List[LegalTip]:
        return db.query(LegalTip).filter(
            and_(
                LegalTip.legal_aid_provider_id == provider_id,
                LegalTip.status != TipStatus.deleted
            )
        ).order_by(LegalTip.created_at.desc()).all()
    
    @staticmethod
    def get_published_tips(db: Session, skip: int = 0, limit: int = 100) -> List[LegalTip]:
        return db.query(LegalTip).filter(
            LegalTip.status == TipStatus.published
        ).order_by(LegalTip.published_at.desc()).offset(skip).limit(limit).all()
    
    @staticmethod
    def get_tips_by_status(db: Session, status: TipStatus, skip: int = 0, limit: int = 100) -> List[LegalTip]:
        return db.query(LegalTip).filter(
            LegalTip.status == status
        ).order_by(LegalTip.created_at.desc()).offset(skip).limit(limit).all()
    
    @staticmethod
    def update_tip(db: Session, tip_id: UUID4, tip_update: LegalTipUpdate) -> Optional[LegalTip]:
        db_tip = db.query(LegalTip).filter(LegalTip.id == tip_id).first()
        if not db_tip:
            return None
        
        update_data = tip_update.dict(exclude_unset=True)
        
        # Set published_at when status changes to published
        if "status" in update_data and update_data["status"] == TipStatus.published:
            update_data["published_at"] = datetime.utcnow()
        
        for field, value in update_data.items():
            setattr(db_tip, field, value)
        
        db.commit()
        db.refresh(db_tip)
        return db_tip
    
    @staticmethod
    def delete_tip(db: Session, tip_id: UUID4) -> bool:
        db_tip = db.query(LegalTip).filter(LegalTip.id == tip_id).first()
        if not db_tip:
            return False
        
        db.delete(db_tip)
        db.commit()
        return True

class LegalRequestCRUD:
    
    @staticmethod
    def create_request(db, request_data):
        new_id = str(uuid.uuid4())
        now = datetime.utcnow()

        insert_stmt = insert(legal_aid_requests).values(
            id=new_id,
            title=request_data.title,
            description=request_data.description,
            user_id=str(request_data.user_id),
            legal_aid_provider_id=str(request_data.legal_aid_provider_id),
            created_at=now,
            status="pending"
        )
        db.execute(insert_stmt)
        db.commit()

        # Fetch the request row
        request_result = db.execute(
            select(legal_aid_requests).where(legal_aid_requests.c.id == new_id)
        ).fetchone()

        request_dict = dict(request_result._mapping)

        # Fetch the user based on user_id
        user_result = db.execute(
            select(users).where(users.c.id == request_data.user_id)
        ).fetchone()

        user_dict = dict(user_result._mapping) if user_result else None
        request_dict["user"] = user_dict

        return request_dict
    
    @staticmethod
    def get_pending_requests_for_provider(db: Session, provider_id: UUID4) -> List[LegalAidRequest]:
        return db.query(LegalAidRequest).filter(
            and_(
                LegalAidRequest.legal_aid_provider_id == provider_id,
                LegalAidRequest.status == RequestStatus.pending
            )
        ).order_by(LegalAidRequest.created_at.desc()).all()
    
    @staticmethod
    def get_processed_requests_for_provider(db: Session, provider_id: UUID4) -> List[LegalAidRequest]:
        return db.query(LegalAidRequest).filter(
            and_(
                LegalAidRequest.legal_aid_provider_id == provider_id,
                LegalAidRequest.status.in_([RequestStatus.accepted, RequestStatus.declined, RequestStatus.completed])
            )
        ).order_by(LegalAidRequest.updated_at.desc()).all()
    
    @staticmethod
    def update_request_status(db: Session, request_id: UUID4, status: RequestStatus) -> Optional[LegalAidRequest]:
        db_request = db.query(LegalAidRequest).filter(LegalAidRequest.id == request_id).first()
        if not db_request:
            return None
        
        db_request.status = status
        db.commit()
        db.refresh(db_request)
        return db_request
