from jwt import InvalidTokenError, ExpiredSignatureError
from fastapi import Request, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from crud import JWT_SECRET_KEY, ALGORITHM
import jwt

# Kept only for legal_provider.py, which still expects this module's
# jwt_bearer/decodeJWT. Everything else uses crud.get_current_user, which
# additionally checks token revocation against the DB — this module doesn't.
# JWT_SECRET_KEY/ALGORITHM come from crud.py so there's a single source of
# truth for the signing secret instead of three copies of the same env read.


def decodeJWT(jwtoken: str):
    try:
        return jwt.decode(jwtoken, JWT_SECRET_KEY, algorithms=[ALGORITHM])
    except ExpiredSignatureError:
        return None
    except InvalidTokenError:
        return None


class JWTBearer(HTTPBearer):
    def __init__(self, auto_error: bool = True):
        super(JWTBearer, self).__init__(auto_error=auto_error)

    async def __call__(self, request: Request):
        credentials: HTTPAuthorizationCredentials = await super(JWTBearer, self).__call__(request)
        if not credentials:
            raise HTTPException(status_code=403, detail="Invalid authorization code.")
        if credentials.scheme != "Bearer":
            raise HTTPException(status_code=403, detail="Invalid authentication scheme.")
        if not self.verify_jwt(credentials.credentials):
            raise HTTPException(status_code=403, detail="Invalid or expired token.")
        return credentials.credentials

    def verify_jwt(self, jwtoken: str) -> bool:
        try:
            jwt.decode(jwtoken, JWT_SECRET_KEY, algorithms=[ALGORITHM])
            return True
        except (ExpiredSignatureError, InvalidTokenError):
            return False


jwt_bearer = JWTBearer()
