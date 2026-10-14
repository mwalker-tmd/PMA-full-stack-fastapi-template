# Diagrams

Visual reference for how this application works. Each diagram describes what the code and configuration in this repository actually do, with the file each one is based on listed with it.

The service topology, request routing and email pipeline are in [ARCHITECTURE.md](../ARCHITECTURE.md), together with the explanation around them.

The diagrams are written in [Mermaid](https://mermaid.js.org), which GitHub renders automatically. To reuse one elsewhere, copy its code block into the [Mermaid Live Editor](https://mermaid.live) and export it as SVG or PNG.

## Contents

* [Database Schema](#database-schema)
* [Authentication](#authentication)
* [Docker Compose Services](#docker-compose-services)
* [CI/CD](#cicd)
* [Deployment](#deployment)
* [Development Workflow](#development-workflow)

## Database Schema

From `backend/app/models.py`. Alembic also keeps an `alembic_version` table recording the latest applied migration.

```mermaid
erDiagram
    USER ||--o{ ITEM : owns
    USER {
        uuid id PK
        string email UK "unique, indexed"
        string hashed_password "Argon2 (or legacy bcrypt)"
        string full_name "optional"
        bool is_active "default true"
        bool is_superuser "default false"
        datetime created_at "UTC"
    }
    ITEM {
        uuid id PK
        string title
        string description "optional"
        uuid owner_id FK "user.id, ON DELETE CASCADE"
        datetime created_at "UTC"
    }
```

Deleting a user deletes their items. Superusers see all items; other users see only their own.

## Authentication

### Logging in and calling the API

From `backend/app/api/routes/login.py`, `backend/app/crud.py`, `backend/app/core/security.py`, `backend/app/api/deps.py` and `frontend/src/hooks/useAuth.ts`.

```mermaid
sequenceDiagram
    actor User
    participant FE as Frontend (React)
    participant API as Backend (FastAPI)
    participant DB as PostgreSQL

    User->>FE: Email + password
    FE->>API: POST /api/v1/login/access-token (form data)
    API->>DB: Find user by email
    alt No such user
        API->>API: Verify against a dummy hash (equal timing)
        API-->>FE: 400 Incorrect email or password
    else User found
        API->>API: pwdlib verify (Argon2, or bcrypt)
        alt Wrong password
            API-->>FE: 400 Incorrect email or password
        else Inactive user
            API-->>FE: 400 Inactive user
        else OK
            opt Stored hash is bcrypt
                API->>DB: Save the password re-hashed with Argon2
            end
            API->>API: Sign JWT (HS256, SECRET_KEY, sub = user id, expires in 8 days)
            API-->>FE: 200 access_token
            FE->>FE: Store token in localStorage
        end
    end

    Note over FE,API: Every later API call
    FE->>API: GET /api/v1/users/me with Authorization: Bearer token
    API->>API: Decode and verify JWT
    alt Invalid or expired token
        API-->>FE: 403 Could not validate credentials
    else Valid
        API->>DB: Load user by id
        API-->>FE: 200 user data
    end
```

### Password reset

From `backend/app/api/routes/login.py` and `backend/app/utils.py`.

```mermaid
sequenceDiagram
    actor User
    participant FE as Frontend
    participant API as Backend
    participant DB as PostgreSQL
    participant Mail as SMTP (Mailpit locally)

    User->>FE: "Forgot your password?", enter email
    FE->>API: POST /api/v1/password-recovery/{email}
    API->>DB: Find user by email
    opt User exists
        API->>API: Create reset token (JWT, sub = email, valid 48 hours)
        API->>API: Render reset_password.html with the link<br/>FRONTEND_HOST/reset-password?token=...
        API->>Mail: Send email
    end
    API-->>FE: Same message whether or not the email exists
    Mail-->>User: Email with the reset link
    User->>FE: Open /reset-password?token=..., enter new password
    FE->>API: POST /api/v1/reset-password/ (token, new_password)
    API->>API: Verify token signature and expiry
    alt Invalid or expired token, or unknown or inactive user
        API-->>FE: 400
    else OK
        API->>DB: Save new Argon2 hash
        API-->>FE: Password updated successfully
    end
```

## Docker Compose Services

How the services depend on each other (`depends_on` in `compose.yml` and `compose.override.yml`), and the one-off preparation step. Dashed boxes exist only in local development.

```mermaid
flowchart TB
    prestart["docker compose run --rm backend<br/>bash scripts/prestart.sh<br/>(migrations + first superuser)"]
    db[("db<br/>PostgreSQL")]
    backend["backend"]
    adminer["adminer"]
    proxy["proxy<br/>Traefik"]
    mailpit["mailpit"]
    playwright["playwright"]
    vol[("volume<br/>app-db-data")]

    db --- vol
    backend -->|"waits until healthy;<br/>restarts with db"| db
    adminer -->|starts after| db
    prestart -->|"waits until healthy"| db
    playwright -->|starts after| backend
    playwright -->|starts after| mailpit
    proxy -.->|"routes to services<br/>with traefik labels"| backend
    proxy -.-> adminer

    classDef localOnly stroke-dasharray: 5 5
    class mailpit,playwright localOnly
```

Health checks: `db` runs `pg_isready`, and `backend` requests `/api/v1/utils/health-check/`. The backend's health check doesn't touch the database, so `backend` can be healthy while database queries fail.

## CI/CD

From `.github/workflows/`. Details: [ci-cd.md](./ci-cd.md).

### Pull requests

```mermaid
flowchart LR
    pr["Pull request opened or updated"]
    pr --> precommit["pre-commit<br/>lint, format, types,<br/>API client freshness"]
    pr --> backend["Test Backend<br/>pytest, coverage at least 90%"]
    pr --> compose["Test Docker Compose<br/>build + start the stack"]
    pr --> changes{"Changed backend/, frontend/,<br/>.env.example, compose*.yml<br/>or playwright.yml?"}
    changes -->|yes| e2e["Playwright<br/>4 shards in parallel"]
    changes -->|no| skip["Playwright skipped<br/>(counts as passing)"]
    pr --> zizmor["Zizmor<br/>workflow security"]
    pr -. "on update" .-> conflicts["Conflict detector<br/>labels conflicting PRs"]
```

CI copies `.env.example` to `.env` and uses no repository secrets, so the same checks pass in a fresh repository and on pull requests from forks.

### Merges to `main`

```mermaid
flowchart TB
    push["Push to main"]
    push --> tests["Test Backend, Test Docker Compose,<br/>Playwright, Zizmor"]
    push --> deploy["Deploy (deploy.yml)"]
    deploy --> check{"FASTAPI_CLOUD_TOKEN and<br/>FASTAPI_CLOUD_APP_ID set?"}
    check -->|no| skipped["Deployment skipped<br/>(notice, run stays green)"]
    check -->|yes| build["Build frontend"] --> prestart["prestart.sh against DATABASE_URL<br/>(migrations + first superuser)"] --> cloud["uv run fastapi deploy<br/>to FastAPI Cloud"]

    manual["Run workflow manually:<br/>Deploy with Docker Compose"] --> runner["Self-hosted runner on your server"]
    runner --> dc["docker compose -f compose.yml -f compose.deploy.yml<br/>build, run prestart.sh, up -d"]
```

The test workflows and the deploy workflow run independently. A deploy doesn't wait for the tests, so protect `main` by requiring passing checks on pull requests before merging.

## Deployment

### Your own server (`compose.deploy.yml`)

```mermaid
flowchart LR
    internet["Internet"]
    subgraph server["Your server (Docker Compose)"]
        proxy["proxy (Traefik)<br/>:80 redirects to :443<br/>Let's Encrypt certificates"]
        backend["backend<br/>FastAPI + built frontend<br/>4 workers"]
        adminer["adminer"]
        db[("db<br/>PostgreSQL")]
        certs[("volume<br/>traefik-certificates")]
        data[("volume<br/>app-db-data")]
    end
    smtp["Your SMTP provider"]

    internet -->|"https://DOMAIN"| proxy
    internet -->|"https://adminer.DOMAIN"| proxy
    proxy --> backend
    proxy --> adminer
    proxy --- certs
    backend --> db
    adminer --> db
    db --- data
    backend -->|"SMTP"| smtp
```

All services restart automatically (`restart: always`). Only Traefik publishes ports (80 and 443). The database isn't reachable from outside the server. Point DNS for both `DOMAIN` and `adminer.DOMAIN` at the server. Guide: [deployment-docker-compose.md](../deployment-docker-compose.md).

### FastAPI Cloud (`deploy.yml`)

```mermaid
flowchart LR
    gha["GitHub Actions<br/>deploy.yml"]
    cloud["FastAPI Cloud<br/>backend + built frontend, HTTPS"]
    db[("Managed PostgreSQL<br/>from your provider")]
    users["Users"]
    smtp["Your SMTP provider"]

    gha -->|"prestart.sh: migrations,<br/>first superuser"| db
    gha -->|"fastapi deploy"| cloud
    users -->|"https://your-app.fastapicloud.dev"| cloud
    cloud -->|"DATABASE_URL"| db
    cloud -->|"SMTP"| smtp
```

The database must be reachable from GitHub's runners as well as from FastAPI Cloud, because the workflow runs the migrations itself. Guide: [deployment.md](../deployment.md).

## Development Workflow

The path a change takes, using this repository's tools.

```mermaid
flowchart TB
    branch["Create a branch"]
    code["Change code<br/>docker compose watch, or local dev servers"]
    api{"Changed backend<br/>routes or models?"}
    migrate["Create a migration<br/>alembic revision --autogenerate"]
    commit["git commit<br/>prek hooks: lint, format, types,<br/>regenerate API client"]
    local["Optional: bash scripts/test-ci-docker.sh"]
    pr["Push + open PR"]
    ci{"CI green?"}
    fix["Fix and push again"]
    merge["Review + merge to main"]
    deploy["deploy.yml deploys<br/>(if FastAPI Cloud is configured)"]

    branch --> code --> api
    api -->|"models changed"| migrate --> commit
    api -->|no| commit
    commit --> local --> pr --> ci
    ci -->|no| fix --> ci
    ci -->|yes| merge --> deploy
```

How to create migrations: [backend/README.md](../backend/README.md).
