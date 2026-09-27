from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from passlib.context import CryptContext
from models import User, LegalAidProvider, Base
# Hardcode DB URL if import fails, or try import
from database import SQLALCHEMY_DATABASE_URL as DATABASE_URL

# Standalone Hashing Logic to avoid Import Errors
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

# Create session
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

def reset_password(email, new_password):
    print(f"Searching for user: {email}")
    user = db.query(User).filter(User.email == email).first()
    
    if not user:
        print("User not found in 'users' table, checking 'legal_aid_providers'...")
        user = db.query(LegalAidProvider).filter(LegalAidProvider.email == email).first()

    if not user:
        print("User not found!")
        # Try finding by name or just listing users to see if we can find them
        users = db.query(User).limit(5).all()
        print("Available regular users:")
        for u in users:
            print(f"- {u.email} ({u.full_name})")
            
        providers = db.query(LegalAidProvider).limit(5).all()
        print("Available legal aid providers:")
        for p in providers:
            print(f"- {p.email} ({p.full_name})")
        return
    
    print(f"User found: {user.full_name} (ID: {user.id})")
    
    # Hash new password
    print("Hashing new password...")
    new_hash = get_password_hash(new_password)
    
    # Update
    user.password_hash = new_hash
    db.commit()
    print(f"Password updated successfully for {email}")
    print(f"New Password: {new_password}")

if __name__ == "__main__":
    target_email = "india@gmail.com" 
    temp_password = "TestPassword123!" 
    
    reset_password(target_email, temp_password)

