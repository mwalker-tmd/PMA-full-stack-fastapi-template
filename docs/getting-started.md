# Getting Started

This guide will help you set up and run the Full Stack FastAPI project on your local machine.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [First Time Setup](#first-time-setup)
- [Running the Application](#running-the-application)
- [Accessing the Application](#accessing-the-application)
- [Next Steps](#next-steps)
- [Common Issues](#common-issues)

## Prerequisites

Before you begin, ensure you have the following installed on your system:

### Required

- **Docker Desktop** (v20.10 or higher)
  - [Download for Mac](https://docs.docker.com/desktop/install/mac-install/)
  - [Download for Windows](https://docs.docker.com/desktop/install/windows-install/)
  - [Download for Linux](https://docs.docker.com/desktop/install/linux-install/)
- **Git** (v2.30 or higher)
  - Check: `git --version`
  - [Install Git](https://git-scm.com/downloads)

### Optional (for local development outside Docker)

- **Python 3.10-3.13** (for backend development)
  - Recommended: Use [uv](https://docs.astral.sh/uv/) for Python environment management
- **Node.js 24+** (for frontend development)
  - Recommended: Use [fnm](https://github.com/Schniz/fnm) or [nvm](https://github.com/nvm-sh/nvm)

## Quick Start

If you just want to see it running:

```bash
# 1. Clone the repository
git clone https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
cd YOUR-REPO-NAME

# 2. Copy environment template
cp .env.example .env

# 3. Generate secure keys (see below)

# 4. Start all services
docker compose watch
```

That's it! The application will be running at http://localhost:5173

## First Time Setup

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
cd YOUR-REPO-NAME
```

### 2. Set Up Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

### 3. Generate Secure Keys

**IMPORTANT**: The `.env.example` file contains placeholder values marked as `changethis`. You must replace these with secure, randomly generated values.

Generate secure keys using Python:

```bash
# Generate SECRET_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Generate FIRST_SUPERUSER_PASSWORD
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Generate POSTGRES_PASSWORD
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Update the following variables in your `.env` file:

```env
SECRET_KEY=<generated-secret-key>
FIRST_SUPERUSER_PASSWORD=<generated-password>
POSTGRES_PASSWORD=<generated-password>
```

**Optional Configuration**:

```env
# Change the default admin email
FIRST_SUPERUSER=your-email@example.com

# Change the project name
PROJECT_NAME="Your Project Name"
STACK_NAME=your-project-name
```

### 4. Understand the .env File

Key environment variables explained:

| Variable | Purpose | Default |
|----------|---------|---------|
| `DOMAIN` | Domain for Traefik routing | `localhost` |
| `ENVIRONMENT` | Environment type | `local` |
| `SECRET_KEY` | JWT token signing | `changethis` ⚠️ |
| `FIRST_SUPERUSER` | Admin email | `admin@example.com` |
| `FIRST_SUPERUSER_PASSWORD` | Admin password | `changethis` ⚠️ |
| `POSTGRES_PASSWORD` | Database password | `changethis` ⚠️ |
| `BACKEND_CORS_ORIGINS` | Allowed CORS origins | Localhost URLs |

⚠️ = Must be changed before deployment

## Running the Application

### Using Docker Compose (Recommended)

Start all services with hot reload:

```bash
docker compose watch
```

This command:
- Builds all Docker images (first time only)
- Starts all services (database, backend, frontend, etc.)
- Watches for file changes and auto-reloads
- Runs database migrations automatically

**Note**: The first time you run this, it will take 5-10 minutes to download images and build containers.

### Verify Services Are Running

Check the status of all containers:

```bash
docker compose ps
```

You should see all services with "Up" status:
- `db` - PostgreSQL database
- `backend` - FastAPI server
- `frontend` - React/Vite dev server
- `proxy` - Traefik reverse proxy
- `adminer` - Database admin UI
- `mailcatcher` - Email testing tool

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f frontend
```

## Accessing the Application

Once all services are running, you can access:

| Service | URL | Purpose |
|---------|-----|---------|
| **Frontend** | http://localhost:5173 | Main application UI |
| **Backend API** | http://localhost:8000 | REST API |
| **API Docs** | http://localhost:8000/docs | Interactive Swagger UI |
| **Alternative Docs** | http://localhost:8000/redoc | ReDoc documentation |
| **Adminer** | http://localhost:8080 | Database management |
| **Traefik Dashboard** | http://localhost:8090 | Proxy status |
| **Mailcatcher** | http://localhost:1080 | Caught emails |

### Login Credentials

Use these credentials to log in at http://localhost:5173:

- **Email**: `admin@example.com` (or the email you set in `.env`)
- **Password**: The value of `FIRST_SUPERUSER_PASSWORD` from your `.env` file

## Next Steps

### 1. Explore the Application

- Log in to the frontend
- Create a new user (Admin → Users → Add User)
- Create some items (Dashboard → Items)
- Check the API docs at http://localhost:8000/docs

### 2. Set Up Pre-commit Hooks (Optional)

Pre-commit hooks ensure code quality before commits:

```bash
cd backend
uv run prek install -f
```

**Note**: Requires Python 3.10-3.13. If you get an error, this is optional for running the app.

### 3. Run Tests

**Backend tests**:
```bash
docker compose exec backend bash /app/scripts/test.sh
```

**Frontend E2E tests**:
```bash
docker compose run --rm playwright npx playwright test
```

### 4. Learn the Codebase

- Read [ARCHITECTURE.md](../ARCHITECTURE.md) for system overview
- Explore [backend/README.md](../backend/README.md) for API development
- Check [frontend/README.md](../frontend/README.md) for UI development
- Review [development.md](../development.md) for detailed dev workflows

### 5. Make Your First Change

Try modifying the homepage:

1. Edit `frontend/src/routes/_layout/index.tsx`
2. Save the file
3. Browser auto-refreshes with your changes

## Common Issues

### Docker Not Running

**Error**: `Cannot connect to the Docker daemon`

**Solution**: Make sure Docker Desktop is running

### Port Already in Use

**Error**: `Bind for 0.0.0.0:5173 failed: port is already allocated`

**Solution**: Another application is using that port. Either:
- Stop the other application
- Change the port in `docker-compose.override.yml`

### Database Connection Failed

**Error**: `connection to server at "db", port 5432 failed`

**Cause**: Database hasn't finished initializing

**Solution**: Wait 30 seconds and try again. First startup is slower.

### "changethis" Warnings in Logs

**Warning**: `The value of SECRET_KEY is "changethis"`

**Solution**: You forgot to update the secure keys in `.env`. See [Generate Secure Keys](#3-generate-secure-keys).

### Hot Reload Not Working

**Issue**: Changes to code don't reflect in browser

**Solution**:
1. Make sure you're using `docker compose watch` (not `up`)
2. Check if the file is mounted correctly:
   ```bash
   docker compose exec backend ls /app/app
   docker compose exec frontend ls /app/src
   ```

### Cannot Access Frontend

**Issue**: http://localhost:5173 shows "Connection refused"

**Troubleshooting**:
```bash
# Check if frontend container is running
docker compose ps frontend

# Check frontend logs
docker compose logs frontend

# Restart the service
docker compose restart frontend
```

### Performance Issues on Mac

**Issue**: Docker containers are slow on macOS

**Solution**:
1. Increase Docker Desktop resources:
   - Open Docker Desktop → Settings → Resources
   - Increase CPUs to 4+ and Memory to 8GB+
2. Use Docker's VirtioFS for better file system performance:
   - Settings → General → Enable VirtioFS

### Need to Reset Everything

If things get really messed up:

```bash
# Stop all containers and remove volumes (deletes database!)
docker compose down -v

# Remove all images
docker compose down --rmi all

# Start fresh
docker compose watch
```

⚠️ **Warning**: This deletes all your data!

## Development Workflows

### Stop the Application

```bash
# Stop all services (keeps data)
docker compose stop

# Stop and remove containers (keeps data)
docker compose down

# Stop and remove containers + volumes (deletes data!)
docker compose down -v
```

### Restart a Single Service

```bash
docker compose restart backend
docker compose restart frontend
```

### Rebuild After Dependency Changes

If you modify `package.json` or `pyproject.toml`:

```bash
# Rebuild and restart
docker compose up -d --build
```

### Access Container Shell

```bash
# Backend
docker compose exec backend bash

# Frontend
docker compose exec frontend sh

# Database
docker compose exec db psql -U postgres -d app
```

### Run Database Migrations

Migrations run automatically on startup. To run manually:

```bash
docker compose exec backend alembic upgrade head
```

### Generate Frontend API Client

When you change the backend API:

```bash
./scripts/generate-client.sh
```

## Getting Help

- **Documentation**: Check `/docs` folder and `*.md` files
- **API Docs**: http://localhost:8000/docs (interactive!)
- **FastAPI Docs**: https://fastapi.tiangolo.com
- **React Docs**: https://react.dev
- **Issues**: Open a GitHub issue in this repository

## What's Next?

Now that you have the application running:

1. **Customize**: Update the project name, colors, and branding
2. **Extend**: Add new API endpoints and pages
3. **Deploy**: Follow [deployment.md](../deployment.md) to go live
4. **Learn**: Read the [architecture docs](../ARCHITECTURE.md) to understand the system

Happy coding! 🚀
