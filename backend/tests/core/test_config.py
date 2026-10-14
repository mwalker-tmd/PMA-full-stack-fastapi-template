from typing import Any

from fastapi.testclient import TestClient

from app.core.config import Settings, settings

VITE_DEV_SERVER = "http://localhost:5173"


def make_settings(**overrides: Any) -> Settings:
    values: dict[str, Any] = {
        "_env_file": None,
        "PROJECT_NAME": "Test",
        "SECRET_KEY": "not-the-default-secret",
        "FIRST_SUPERUSER": "admin@example.com",
        "FIRST_SUPERUSER_PASSWORD": "not-the-default-password",
        "DATABASE_URL": "postgresql://postgres:secret@localhost:5432/app",
        "FASTAPI_ENV": None,
    }
    values.update(overrides)
    return Settings(**values)


def test_cors_origins_outside_development_is_only_frontend_host() -> None:
    s = make_settings(FRONTEND_HOST="https://app.example.com")
    assert s.all_cors_origins == ["https://app.example.com"]


def test_cors_origins_in_development_adds_vite_dev_server() -> None:
    s = make_settings(FRONTEND_HOST="http://localhost:8000", FASTAPI_ENV="development")
    assert s.all_cors_origins == ["http://localhost:8000", VITE_DEV_SERVER]


def test_cors_origins_in_development_does_not_duplicate_vite_dev_server() -> None:
    s = make_settings(FRONTEND_HOST=VITE_DEV_SERVER, FASTAPI_ENV="development")
    assert s.all_cors_origins == [VITE_DEV_SERVER]


def test_cors_preflight_allows_vite_dev_server_in_development(
    client: TestClient,
) -> None:
    assert settings.FASTAPI_ENV == "development"
    r = client.options(
        f"{settings.API_V1_STR}/login/access-token",
        headers={
            "Origin": VITE_DEV_SERVER,
            "Access-Control-Request-Method": "POST",
        },
    )
    assert r.status_code == 200
    assert r.headers["access-control-allow-origin"] == VITE_DEV_SERVER


def test_cors_preflight_rejects_other_local_origin_in_development(
    client: TestClient,
) -> None:
    other_origin = "http://localhost:5174"
    assert other_origin not in settings.all_cors_origins
    r = client.options(
        f"{settings.API_V1_STR}/login/access-token",
        headers={
            "Origin": other_origin,
            "Access-Control-Request-Method": "POST",
        },
    )
    assert r.status_code == 400
    assert "access-control-allow-origin" not in r.headers
