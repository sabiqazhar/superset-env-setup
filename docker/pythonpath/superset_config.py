import os

# ==========================================================
# Security
# ==========================================================

SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "CHANGE_ME")

# ==========================================================
# Metadata Database
# ==========================================================

SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://"
    f"{os.getenv('POSTGRES_USER')}:"
    f"{os.getenv('POSTGRES_PASSWORD')}@"
    f"{os.getenv('POSTGRES_HOST', 'postgres')}:"
    f"{os.getenv('POSTGRES_PORT', '5432')}/"
    f"{os.getenv('POSTGRES_DB')}"
)

# ==========================================================
# Redis
# ==========================================================

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": REDIS_DB,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_DEFAULT_TIMEOUT": 86400,
}

# Dashboard / Chart query cache
DATA_CACHE_CONFIG = CACHE_CONFIG

# Native filter cache
FILTER_STATE_CACHE_CONFIG = CACHE_CONFIG

# Explore form cache
EXPLORE_FORM_DATA_CACHE_CONFIG = CACHE_CONFIG
