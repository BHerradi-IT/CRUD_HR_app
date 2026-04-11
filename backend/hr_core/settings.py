def get_database_config():
    database_url = os.getenv("DATABASE_URL")

    # ===============================
    # 1. Docker / Production (PostgreSQL)
    # ===============================
    if database_url:
        parsed = urlparse(database_url)

        if parsed.scheme not in {"postgres", "postgresql"}:
            raise ValueError("Only PostgreSQL DATABASE_URL is supported")

        return {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": unquote(parsed.path.lstrip("/")),
            "USER": unquote(parsed.username or ""),
            "PASSWORD": unquote(parsed.password or ""),
            "HOST": parsed.hostname,
            "PORT": parsed.port or 5432,
            "CONN_MAX_AGE": int(os.getenv("DATABASE_CONN_MAX_AGE", "60")),
            "ATOMIC_REQUESTS": True,
        }

    # ===============================
    # 2. Docker fallback (VERY IMPORTANT FIX)
    # ===============================
    return {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.getenv("POSTGRES_DB", "ytech_hr"),
        "USER": os.getenv("POSTGRES_USER", "hr_app_user"),
        "PASSWORD": os.getenv("POSTGRES_PASSWORD", "LocalPostgres12345!"),
        "HOST": os.getenv("POSTGRES_HOST", "postgres"),
        "PORT": os.getenv("POSTGRES_PORT", "5432"),
        "CONN_MAX_AGE": 60,
        "ATOMIC_REQUESTS": True,
    }
