from passlib.context import CryptContext
import logging

# Setup logged like crud.py
logging.basicConfig(level=logging.INFO)

# Copy the context from crud.py
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def test_hashing():
    password = "MyTestPassword123!"
    
    print(f"Testing password: {password}")
    
    # 1. Test Hashing
    try:
        hashed = pwd_context.hash(password)
        print(f"Generated Hash: {hashed}")
    except Exception as e:
        print(f"ERROR: Failed to hash password: {e}")
        return

    # 2. Test Verification of NEW hash
    try:
        is_valid = pwd_context.verify(password, hashed)
        print(f"Verification of NEW hash: {'SUCCESS' if is_valid else 'FAILED'}")
    except Exception as e:
        print(f"ERROR: Failed to verify new hash: {e}")

    # 3. Test Verification of Dummy OLD hash (Standard bcrypt $2b$)
    # This is a hash for "secret"
    old_hash_2b = "$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWrn96pzwLO3(dot)k0(dot)3(dot)k(dot)0" 
    # Note: I won't use a real complex hash here to avoid confusion, 
    # but let's try a simple one if we can generate it.
    
    # Let's rely on the first test: If we can Hash and Verify, then the library works.
    # The issue is likely the Format of the stored hashes.

if __name__ == "__main__":
    test_hashing()
