from slowapi import Limiter
from slowapi.util import get_remote_address
import sys

is_testing = "pytest" in sys.modules
limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"], enabled=not is_testing)
