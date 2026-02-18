import re
from unittest.mock import Base
from pydantic import BaseModel, ConfigDict, EmailStr, UUID4, validator
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
from typing import Optional
from decimal import Decimal
from datetime import datetime
from enum import Enum

from sqlalchemy import TIMESTAMP

from models import TipStatus

'''
So this ka code is like to sort of set the design ya the processes 
So like kama login will be done using phone no and password
alafu kama ku update you can  update information like phone no etc but huwezi update ids , created at you get

'''
# ===============================
# User Schemas
# ===============================

class UserBase(BaseModel):
    full_name: str
    phone_number: str
    email: EmailStr
    role_id: int
    profile_image: Optional[str] = None

    emergency_contact_name: Optional[str] = None
    emergency_contact_number: Optional[str] = None
    emergency_contact_email: Optional[EmailStr] = None

class CreateUser(UserBase):
    password_hash: Optional[str] = None
    role_id: int
    google_oauth: Optional[bool] = False  # Flag for Google users
    @validator("password_hash")
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain at least one digit")
        if not re.search(r"[^A-Za-z0-9]", v):
            raise ValueError("Password must contain at least one special character")
        return v

class LoginGoogleUser(BaseModel):
    email: EmailStr

class LoginUser(BaseModel):
    identifier: str
    password_hash: str

class UpdateUser(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[EmailStr] = None
    password_hash: Optional[str] = None

class ShowUser(UserBase):
    id: UUID4

    model_config = {
        "from_attributes": True
    }

class TokenSchema(BaseModel):
    access_token: str
    refresh_token: str

class changepassword(BaseModel):
    email:str
    old_password:str
    new_password:str

class TokenCreate(BaseModel):
    user_id:str
    access_token:str
    refresh_token:str
    status:bool
    created_date: datetime

class UserResponse(BaseModel):
    id: UUID4
    full_name: str
    email: EmailStr
    phone_number: str

    model_config = {
        "from_attributes": True
    }



# Legal Aid Provider schemas
class editprofile(BaseModel):
    old_password: str
    new_password: str
    full_name: str
    email: str
    phone_number: str
    profile_image: Optional[str] = None
    
    # Emergency contact fields (for regular users)
    emergency_contact_name: Optional[str] = None
    emergency_contact_email: Optional[str] = None
    emergency_contact_number: Optional[str] = None
    
    # Legal aid specific fields
    expertise_area_ids: Optional[List[int]] = None

class TokenCreate(BaseModel):
    user_id: str
    access_token: str
    refresh_token: str
    status: bool
    created_date: datetime

class ExpertiseAreaBase(BaseModel):
    name: str

class ExpertiseAreaCreate(ExpertiseAreaBase):
    pass

class ExpertiseAreaOut(ExpertiseAreaBase):
    id: int
class showExpertiseArea(ExpertiseAreaBase):
    id: int
    name: str

    model_config = {
        "from_attributes": True
    }

class editprofile(BaseModel):
    old_password: str
    new_password: str
    full_name: str
    email: str
    phone_number: str
    profile_image: Optional[str] = None

class LegalAidProviderBase(BaseModel):
    full_name: str
    phone_number: str
    email: EmailStr
    status: str
    profile_image: Optional[str] = None
    psk_number: str
    about: Optional[str] = None

class CreateLegalAid(LegalAidProviderBase):
    password_hash: Optional[str] = None # For traditional users
    role_id: int
    google_oauth: Optional[bool] = False
    expertise_area_ids: List[int]  # List of expertise area IDs
    @validator("password_hash")
    def validate_password(cls, v):
        if v is None:
            raise ValueError("Password cannot be empty")
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain at least one digit")
        if not re.search(r"[^A-Za-z0-9]", v):
            raise ValueError("Password must contain at least one special character")
        return v

class LoginLglAidGoogleUser(BaseModel):
    email: EmailStr

class LoginLegalAid(BaseModel):
    identifier: str  # Can be phone or email
    password_hash: Optional[str] = None

class UpdateLegalAid(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[EmailStr] = None
    password_hash: Optional[str] = None
    status: Optional[str] = None
    profile_image: Optional[str] = None
    psk_number: Optional[str] = None
    expertise_area_ids: Optional[List[int]] = None
    about: Optional[str] = None

class ShowLegalAid(LegalAidProviderBase):
    id: UUID4
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[str] = None
    psk_number: Optional[str] = None
    status: Optional[str] = None
    profile_image: Optional[str] = None
    about: Optional[str] = None
    created_at: datetime
    
    model_config = {
        "from_attributes": True
    }

class RequestStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    declined = "declined"
    completed = "completed"
class LegalAidRequestBase(BaseModel):
    title: str
    description: str
    status: Optional[RequestStatus] = RequestStatus.pending
class CreateLegalAidRequest(LegalAidRequestBase):
    user_id: UUID4
    legal_aid_provider_id: UUID4
class UpdateLegalAidRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[RequestStatus] = None
    legal_aid_provider_id: Optional[UUID4] = None
class ShowLegalAidRequest(LegalAidRequestBase):
    id: int
    user_id: UUID4
    legal_aid_provider_id: UUID4
    created_at: datetime
    user: Optional[UserBase] = None
    legal_aid_provider: Optional[ShowLegalAid] = None  # Change this from LegalAidProviderBase to ShowLegalAid

    model_config = {
        "from_attributes": True
    }

class LegalTipBase(BaseModel):
    title: str
    description: str
    image_url: Optional[str] = None

class LegalTipCreate(LegalTipBase):
    legal_aid_provider_id: UUID4

class LegalTipUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    status: Optional[TipStatus] = None

class LegalTipResponse(LegalTipBase):
    id: UUID4
    status: TipStatus
    legal_aid_provider_id: UUID4
    created_at: datetime
    updated_at: datetime
    published_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class LegalAidRequestCreate(BaseModel):
    title: str
    description: str
    user_id: UUID4
    legal_aid_provider_id: UUID4

class LegalAidRequestUpdate(BaseModel):
    status: RequestStatus

class UserOut(BaseModel):
    id: UUID4
    full_name: str
    email: str
    phone_number: str

    class Config:
        from_attributes = True

class LegalAidRequestResponse(BaseModel):
    id: UUID4
    title: str
    description: str
    user_id: UUID4
    legal_aid_provider_id: UUID4
    created_at: datetime
    status: str
    user: Optional[UserOut]

    class Config:
        from_attributes = True



class LegalAidRequestOut(BaseModel):
    id: str
    user_id: UUID4
    legal_aid_provider_id: UUID4
    title: str
    description: str
    status: str
    created_at: datetime
    user: Optional[UserOut]  # <- nested user

    class Config:
        from_attributes = True



class LegalTipBase(BaseModel):
    title: str
    description: str
    image_url: Optional[str] = None
    status: Optional[TipStatus] = TipStatus.draft

class CreateLegalTip(BaseModel):
    title: str
    description: str
    image_url: Optional[str] = None
    legal_aid_provider_id: UUID4

class UpdateLegalTip(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    status: Optional[TipStatus] = None



class ShowLegalTip(BaseModel):
    id: UUID4
    title: str
    description: str
    image_url: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    legal_aid_provider_id: UUID4
    legal_aid_provider: Optional[ShowLegalAid] = None  # Add this line

    model_config = {
        "from_attributes": True
    }
    
    

class LegalTipWithProvider(ShowLegalTip):
    legal_aid_provider: ShowLegalAid


# Updated schemas for better base64 handling
class CreateLegalTipRequest(BaseModel):
    title: str
    description: str
    image_base64: Optional[str] = None  # base64 encoded image
    status: Optional[TipStatus] = TipStatus.draft
    legal_aid_provider_id: UUID4

class UpdateLegalTipRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    image_base64: Optional[str] = None  # base64 encoded image
    status: Optional[TipStatus] = None

class Base64ImageUpload(BaseModel):
    image_data: str  # base64 encoded image
    filename: Optional[str] = None

class UserDistributionResponse(BaseModel):
    total_users: int
    legal_aid_providers: int
    admins: int


class DangerZoneDataPoint(BaseModel):
    location_name: str
    reported_count: int

class DangerZonesResponse(BaseModel):
    data: List[DangerZoneDataPoint]
    total_incidents: int

class AnalyticsResponse(BaseModel):
    user_distribution: UserDistributionResponse
    danger_zones: DangerZonesResponse

    expertise_area: Optional[str] = None



class EmergencyContactBase(BaseModel):
    contact_name: str
    contact_number: str
    email_contact: Optional[EmailStr] = None

class CreateEmergencyContact(EmergencyContactBase):
    user_id: UUID4

class UpdateEmergencyContact(BaseModel):
    contact_name: Optional[str] = None
    contact_number: Optional[str] = None
    email_contact: Optional[EmailStr] = None

class ShowEmergencyContact(EmergencyContactBase):
    id: int

    model_config = {
        "from_attributes": True
    }



class PanicInfoBase(BaseModel):
    longitude: float
    latitude: float
    status: Optional[str] = "Pending"
    emergency_contact_notified: Optional[bool] = False
    hotline_notified: Optional[bool] = False
    additional_notes: Optional[str] = None

class CreatePanicInfo(PanicInfoBase):
    user_id: UUID4

class UpdatePanicInfo(BaseModel):
    status: Optional[str] = None
    emergency_contact_notified: Optional[bool] = None
    hotline_notified: Optional[bool] = None
    additional_notes: Optional[str] = None

class ShowPanicInfo(PanicInfoBase):
    id: int

    model_config = {
        "from_attributes": True
    }



class NotificationBase(BaseModel):
    receiver_contact: str
    message: str
    status: str

class CreateNotification(NotificationBase):
    panic_info_id: int

class ShowNotification(NotificationBase):
    id: int

    model_config = {
        "from_attributes": True
    }



class Role(BaseModel):
    id: int
    name: str

    model_config = {
        "from_attributes": True
    }



class UserLegalMatchBase(BaseModel):
    user_id: UUID4
    legal_aid_id: UUID4
    status: str

class ShowUserLegalMatch(UserLegalMatchBase):
    id: int

    model_config = {
        "from_attributes": True
    }



class Activity(BaseModel):
    id: int
    name: str

    model_config = {
        "from_attributes": True
    }

class RealTimeGPSLogBase(BaseModel):
    user_id: UUID4
    activity_id: int
    latitude: float
    longitude: float
    recorded_at: Optional[datetime] = None

class RealTimeGPSLogCreate(RealTimeGPSLogBase):
    pass

class RealTimeGPSLogShow(RealTimeGPSLogBase):
    id: int

    model_config = {
        "from_attributes": True
    }

class SafetyTipBase(BaseModel):
    title: str
    content: str
    submitted_by: UUID4
    submitted_by_role: str
    status: str

class SafetyTipShow(SafetyTipBase):
    id: int
    created_at: datetime

    class Config:
        orm_mode = True




class DangerZoneBase(BaseModel):
    location_name: str
    latitude: float
    longitude: float
    description: Optional[str] = None
    reported_count: Optional[int] = 0

class DangerZoneCreate(DangerZoneBase):
    pass

class DangerZoneShow(DangerZoneBase):
    id: int
class DangerZoneResponse(DangerZoneBase):
    id: int

    model_config = {
        "from_attributes": True
    }

class PoliceLocationBase(BaseModel):
    name: str
    latitude: float
    longitude: float
   



class PoliceLocationCreate(BaseModel):
    name: str
    latitude: float
    longitude: float
  

class PoliceLocationUpdate(BaseModel):
    name: str
    latitude: float
    longitude: float
   

class PoliceLocationShow(PoliceLocationBase):
    id: int
    name: str
    latitude:float
    longitude: float
  
class PoliceLocationResponse(BaseModel):
    id: int
    name: str
    latitude: float
    longitude: float
    


    model_config = {
        "from_attributes": True
    }

class ProximityAlert(BaseModel):
    user_latitude: float
    user_longitude: float
    radius: Optional[float] = 1000.0  # Check within 1km by default

class ProximityResponse(BaseModel):
    nearby_police: List[PoliceLocationResponse]
    nearby_dangers: List[DangerZoneResponse]
    warnings: List[str]


class PreviousFemicideDataBase(BaseModel):
    medium: str
    county: str
    text: str
    date: datetime
    type_of_murder: str
    victim_age: int
    date_of_murder: datetime
    location: str
    suspect_relationship: str
    type_of_femicide: str
    murder_scene: str
    killing_mode: str
    circumstances: str
    status_on_arrest: str
    court_date: Optional[datetime] = None
    verdict_date: Optional[datetime] = None
    verdict: str
    sentence_years: int
    days_to_verdict: int

class PreviousFemicideDataCreate(PreviousFemicideDataBase):
    pass

class PreviousFemicideDataShow(PreviousFemicideDataBase):
    id: int

    model_config = {
        "from_attributes": True
    }


# Request schemas (for API input)
class SMSRequest(BaseModel):
    phone_number: str
    message: str
    is_emergency: Optional[bool] = False

class LocationSMSRequest(BaseModel):
    phone_number: str
    message: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None

# Response schemas (for API output)
class SMSResponse(BaseModel):
    id: int
    phone_number: str
    message: str
    is_emergency: bool
    sent_at: datetime
    
    class Config:
        from_attributes = True

class LocationSMSResponse(BaseModel):
    id: int
    phone_number: str
    message: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    sent_at: datetime
    
    class Config:
        from_attributes = True

# If you need these for creating database records
class SMSCreate(BaseModel):
    phone_number: str
    message: str
    is_emergency: bool = False

class LocationSMSCreate(BaseModel):
    phone_number: str
    message: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    
class RealTimeGPSLogCreate(BaseModel):
    activity_id: int
    latitude: float
    longitude: float


class RealTimeGPSLogShow(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    user_id: UUID4
    activity_id: int
    latitude: float
    longitude: float
    recorded_at: datetime


class LocationSharingSessionCreate(BaseModel):
    activity_id: int
    contacts: List[str]
    duration_hours: int = 24


class LocationSharingSessionShow(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    user_id: UUID4
    activity_id: int
    session_token: str
    contacts: str  # JSON string
    expires_at: datetime
    created_at: datetime
    is_active: bool


class UserShow(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: str
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone_number: Optional[str] = None
    created_at: datetime


class ActivityCreate(BaseModel):
    name: str
    description: Optional[str] = None


class ActivityShow(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    user_id: UUID4
    name: str
    description: Optional[str] = None
    created_at: datetime
    is_active: bool
