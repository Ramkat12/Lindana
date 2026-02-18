import enum
from typing import List, Optional
from database import Base
from sqlalchemy import (
    Column, String, Integer, TIMESTAMP, ForeignKey, Table, Text, Boolean, DateTime,
    DECIMAL, text, Float, Enum
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship, Mapped, mapped_column
import uuid
from datetime import datetime

from enum import Enum
from sqlalchemy import Enum as SQLEnum

legal_provider_expertise = Table(
    "legal_provider_expertise",
    Base.metadata,
    Column("provider_id", UUID(as_uuid=True), ForeignKey("legal_aid_providers.id")),
    Column("expertise_id", Integer, ForeignKey("expertise_areas.id"))
)

class Role(Base):
    __tablename__ = "roles"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False)

    users = relationship("User", back_populates="role")
    legal_providers = relationship("LegalAidProvider", back_populates="role")

class User(Base):
    __tablename__ = "users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name = Column(String(255))
    phone_number = Column(String(20), unique=True)
    email = Column(String(255), unique=True)
    password_hash = Column(Text)
    role_id = Column(Integer, ForeignKey("roles.id"))
    profile_image = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP, server_default=text("now()"))

    role = relationship("Role", back_populates="users")
    safety_tips = relationship("SafetyTip", back_populates="submitted_by_user")
    panic_info = relationship("PanicInfo", back_populates="user")
    emergency_contacts = relationship("EmergencyContact", back_populates="user", cascade="all, delete-orphan")
    gps_logs = relationship("RealTimeGPSLog", back_populates="user")
    sharing_sessions = relationship("LocationSharingSession", back_populates="user")
    legal_aid_requests = relationship("LegalAidRequest", back_populates="user")

class ExpertiseArea(Base):
    __tablename__ = "expertise_areas"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True, nullable=False)

    providers = relationship(
        "LegalAidProvider",
        secondary=legal_provider_expertise,
        back_populates="expertise_areas"
    )



class LegalAidProvider(Base):
    __tablename__ = "legal_aid_providers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name = Column(String(255))
    phone_number = Column(String(20), unique=True)
    email = Column(String(255), unique=True)
    password_hash = Column(Text)

    # Removed: expertise_area = Column(...)
    expertise_areas = relationship(
        "ExpertiseArea",
        secondary=legal_provider_expertise,
        back_populates="providers"
    )

    status = Column(String(50))
    profile_image = Column(Text, nullable=True)
    psk_number = Column(String(50), unique=True, nullable=False)
    created_at = Column(TIMESTAMP, server_default=text("now()"))
    role_id = Column(Integer, ForeignKey("roles.id"))
    about = Column(Text, nullable=True)

    role = relationship("Role", back_populates="legal_providers")
    safety_tips = relationship("SafetyTip", back_populates="submitted_by_legal")
    requests_received = relationship("LegalAidRequest", back_populates="legal_aid_provider")
    legal_tips = relationship("LegalTip", back_populates="legal_aid_provider")

class RequestStatusEnum(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    declined = "declined"
    completed = "completed"

class TipStatus(str, enum.Enum):
    draft = "draft"
    published = "published"
    archived = "archived"
    deleted = "deleted"

class LegalTip(Base):
    __tablename__ = "legal_tips"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    image_url = Column(Text, nullable=True)
    status = Column(SQLEnum(TipStatus, name="tipstatus"), default=TipStatus.draft)
    legal_aid_provider_id = Column(UUID(as_uuid=True), ForeignKey("legal_aid_providers.id"), nullable=False)
    created_at = Column(TIMESTAMP, server_default=text("now()"))
    updated_at = Column(TIMESTAMP, server_default=text("now()"), onupdate=text("now()"))
    published_at = Column(TIMESTAMP, nullable=True)
    
    # Relationships
    legal_aid_provider = relationship("LegalAidProvider", back_populates="legal_tips")



class LegalAidRequest(Base):
    __tablename__ = "legal_aid_requests"

    id = Column(Integer, primary_key=True, index=True)
    
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    legal_aid_provider_id = Column(UUID(as_uuid=True), ForeignKey("legal_aid_providers.id"), nullable=False)
    
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    
    status = Column(SQLEnum(RequestStatusEnum, name="request_status"), nullable=False, default=RequestStatusEnum.pending)

    
    created_at = Column(TIMESTAMP, server_default=text("now()"))
    

    # Relationships
    user = relationship("User", back_populates="legal_aid_requests")
    legal_aid_provider = relationship("LegalAidProvider", back_populates="requests_received")
  

class SafetyTip(Base):
    __tablename__ = "safety_tips"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255))
    content = Column(Text)
    submitted_by_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    submitted_by_legal_id = Column(UUID(as_uuid=True), ForeignKey("legal_aid_providers.id"), nullable=True)
    created_at = Column(TIMESTAMP, server_default=text("now()"))
    status = Column(String(50))

    submitted_by_user = relationship("User", back_populates="safety_tips")
    submitted_by_legal = relationship("LegalAidProvider", back_populates="safety_tips")

class UserLegalMatch(Base):
    __tablename__ = "user_legal_matches"
    id = Column(Integer, primary_key=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    legal_aid_id = Column(UUID(as_uuid=True), ForeignKey("legal_aid_providers.id"))
    matched_at = Column(TIMESTAMP, server_default=text("now()"))
    status = Column(String(50))

class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"
    id = Column(Integer, primary_key=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    contact_name = Column(String(255))
    contact_number = Column(String(20))
    email_contact = Column(String(255))

    user = relationship("User", back_populates="emergency_contacts")

class PanicInfo(Base):
    __tablename__ = "panic_info"
    id = Column(Integer, primary_key=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    pressed_at = Column(TIMESTAMP, server_default=text("now()"))
    latitude = Column(DECIMAL(9, 6))
    longitude = Column(DECIMAL(9, 6))
    status = Column(String(50))
    emergency_contact_notified = Column(Boolean, default=False)
    hotline_notified = Column(Boolean, default=False)
    additional_notes = Column(Text)

    user = relationship("User", back_populates="panic_info")

class DangerZone(Base):
    __tablename__ = "danger_zones"
    id = Column(Integer, primary_key=True, index=True)
    location_name = Column(String(255))
    longitude = Column(DECIMAL(9, 6))
    latitude = Column(DECIMAL(9, 6))
    description = Column(Text)
    reported_count = Column(Integer, server_default=text("0"))




class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True)
    panic_info_id = Column(Integer, ForeignKey("panic_info.id"))
    message = Column(Text)
    created_at = Column(TIMESTAMP, server_default=text("now()"))


class UserTokenTable(Base):
    __tablename__ = "user_tokens"
    user_id = Column(UUID(as_uuid=True), ForeignKey('users.id'))
    access_token = Column(String(450), primary_key=True)
    refresh_token = Column(String(450), nullable=False)
    status = Column(Boolean)
    created_date = Column(TIMESTAMP, server_default=text("now()"))


class LegalAidTokenTable(Base):
    __tablename__ = "legal_aid_tokens"
    provider_id = Column(UUID(as_uuid=True), ForeignKey('legal_aid_providers.id'))
    access_token = Column(String(450), primary_key=True)
    refresh_token = Column(String(450), nullable=False)
    status = Column(Boolean)
    created_date = Column(TIMESTAMP, server_default=text("now()"))


class EmergencyLog(Base):
    __tablename__ = "emergency_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    type = Column(String(50), nullable=False)  # 'emergency', 'location_share'
    message = Column(Text, nullable=False)
    recipients = Column(Text)  # JSON string instead of JSON type
    latitude = Column(DECIMAL(10, 8))
    longitude = Column(DECIMAL(11, 8))
    trigger_method = Column(String(50))  # 'shake', 'button', 'manual'
    sms_results = Column(Text)  # JSON string instead of JSON type
    created_at = Column(TIMESTAMP, server_default=text("now()"))


class SMSRequest(Base):
    __tablename__ = "sms_logs"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(20), nullable=False)
    message = Column(Text, nullable=False)
    is_emergency = Column(Boolean, default=False)
    sent_at = Column(TIMESTAMP, server_default=text("now()"))


class LocationSMSRequest(Base):
    __tablename__ = "location_sms_logs"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(20), nullable=False)
    message = Column(Text, nullable=False)
    latitude = Column(DECIMAL(9, 6), nullable=True)
    longitude = Column(DECIMAL(9, 6), nullable=True)
    sent_at = Column(TIMESTAMP, server_default=text("now()"))


# Create Activities table first (referenced by RealTimeGPSLog)
class Activity(Base):
    __tablename__ = "activities"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP, server_default=text("now()"))
    is_active = Column(Boolean, default=True)


class RealTimeGPSLog(Base):
    __tablename__ = "realtime_gps_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    activity_id = Column(Integer, ForeignKey("activities.id"))
    latitude = Column(Float)
    longitude = Column(Float)
    recorded_at = Column(TIMESTAMP, server_default=text("now()"))

    # Relationships
    user = relationship("User", back_populates="gps_logs")
class PoliceLocation(Base):
    __tablename__ = "police_locations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    latitude = Column(DECIMAL(9, 6), nullable=False)
    longitude = Column(DECIMAL(9, 6), nullable=False)
    



class LocationSharingSession(Base):
    __tablename__ = "location_sharing_sessions"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey('users.id'))
    activity_id = Column(Integer, nullable=False)
    session_token = Column(String(255), unique=True, default=lambda: str(uuid.uuid4()))
    contacts = Column(String(1000))  # JSON string of contact list
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(TIMESTAMP, server_default=text("now()"))
    is_active = Column(Boolean, default=True)
    
    user = relationship("User", back_populates="sharing_sessions")


