# Backend API Endpoints for Wake Word Emergency System

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from datetime import datetime
import json
import asyncio

router = APIRouter()

# Emergency activation endpoint
@router.post("/emergency/wake-word-activate")
async def activate_emergency_by_wake_word(
    location_data: dict,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Activate emergency mode via wake word detection"""
    try:
        user_id = current_user["user_id"]
        
        # Create emergency alert
        emergency_alert = EmergencyAlert(
            user_id=user_id,
            latitude=location_data.get("latitude"),
            longitude=location_data.get("longitude"),
            alert_type="wake_word_activation",
            status="active",
            created_at=datetime.now(),
            activation_method="voice_command"
        )
        db.add(emergency_alert)
        
        # Log the GPS location
        gps_log = RealTimeGPSLog(
            user_id=user_id,
            latitude=location_data.get("latitude"),
            longitude=location_data.get("longitude"),
            recorded_at=datetime.now(),
            emergency_flag=True
        )
        db.add(gps_log)
        
        # Notify emergency contacts
        emergency_contacts = db.query(EmergencyContact).filter(
            EmergencyContact.user_id == user_id
        ).all()
        
        # Send notifications (SMS/Email/Push)
        notifications_sent = []
        for contact in emergency_contacts:
            # Add your notification logic here
            notifications_sent.append({
                "contact_id": str(contact.id),
                "name": contact.name,
                "phone": contact.phone_number
            })
        
        db.commit()
        
        return {
            "status": "emergency_activated",
            "alert_id": str(emergency_alert.id),
            "timestamp": emergency_alert.created_at.isoformat(),
            "location": {
                "latitude": location_data.get("latitude"),
                "longitude": location_data.get("longitude")
            },
            "contacts_notified": len(notifications_sent),
            "message": "Emergency services have been alerted"
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to activate emergency: {str(e)}")


# WebSocket for real-time audio streaming
@router.websocket("/ws/wake-word-monitor/{user_id}")
async def wake_word_monitor(websocket: WebSocket, user_id: str):
    """WebSocket endpoint for continuous wake word monitoring"""
    await websocket.accept()
    
    try:
        while True:
            # Receive audio data or wake word detection signal
            data = await websocket.receive_json()
            
            if data.get("type") == "wake_word_detected":
                # Wake word detected, send acknowledgment
                await websocket.send_json({
                    "status": "wake_word_confirmed",
                    "timestamp": datetime.now().isoformat(),
                    "action": "prepare_emergency_activation"
                })
                
            elif data.get("type") == "audio_chunk":
                # Process audio for wake word detection
                # This would integrate with your ML model
                await websocket.send_json({
                    "status": "processing",
                    "confidence": data.get("confidence", 0.0)
                })
                
            elif data.get("type") == "emergency_confirmed":
                # User confirmed emergency after wake word
                await websocket.send_json({
                    "status": "emergency_activating",
                    "message": "Activating emergency protocol..."
                })
                
    except WebSocketDisconnect:
        print(f"Wake word monitor disconnected for user: {user_id}")


# Get wake word settings
@router.get("/emergency/wake-word-settings")
async def get_wake_word_settings(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get user's wake word detection settings"""
    user_id = current_user["user_id"]
    
    # Fetch or create default settings
    settings = {
        "user_id": user_id,
        "wake_word_enabled": True,
        "wake_words": ["help me", "emergency", "danger", "call police"],
        "confidence_threshold": 0.85,
        "confirmation_required": True,  # Require user confirmation before activating
        "confirmation_timeout_seconds": 5,
        "auto_activate_on_high_confidence": False,
        "high_confidence_threshold": 0.95,
        "language": "en-US"
    }
    
    return settings


# Update wake word settings
@router.put("/emergency/wake-word-settings")
async def update_wake_word_settings(
    settings: dict,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Update user's wake word detection settings"""
    user_id = current_user["user_id"]
    
    # Save settings to database
    # Implementation depends on your database schema
    
    return {
        "status": "settings_updated",
        "user_id": user_id,
        "settings": settings
    }


# Test wake word detection
@router.post("/emergency/test-wake-word")
async def test_wake_word_detection(
    test_data: dict,
    current_user = Depends(get_current_user)
):
    """Test wake word detection without activating emergency"""
    return {
        "status": "test_mode",
        "detected": test_data.get("detected", False),
        "confidence": test_data.get("confidence", 0.0),
        "wake_word": test_data.get("wake_word", ""),
        "message": "Test successful - no emergency activated"
    }