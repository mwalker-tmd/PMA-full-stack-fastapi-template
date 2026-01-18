# Troubleshooting Guide

This guide covers common issues you might encounter while developing or deploying the Full Stack FastAPI application.

## Table of Contents

- [Docker Issues](#docker-issues)
- [Database Issues](#database-issues)
- [Backend Issues](#backend-issues)
- [Frontend Issues](#frontend-issues)
- [Network & Connectivity](#network--connectivity)
- [Performance Issues](#performance-issues)
- [Production Issues](#production-issues)

---

## Docker Issues

### Docker Daemon Not Running

**Symptoms**:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solution**:
1. Start Docker Desktop (Mac/Windows)
2. On Linux: `sudo systemctl start docker`
3. Verify: `docker ps`

---

### Port Already in Use

**Symptoms**:
```
Bind for 0.0.0.0:5173 failed: port is already allocated
```

**Solution**:

**Option 1** - Stop the conflicting service:
```bash
# Find what's using the port
lsof -i :5173

# Kill the process
kill -9 <PID>
```

**Option 2** - Change the port in `docker-compose.override.yml`:
```yaml
frontend:
  ports:
    - "5174:80"  # Changed from 5173
```

---

### Container Keeps Restarting

**Symptoms**:
```bash
docker compose ps
# Shows container in "Restarting" status
```

**Diagnosis**:
```bash
# Check logs for errors
docker compose logs <service-name>

# Check last 50 lines
docker compose logs --tail=50 <service-name>

# Follow logs in real-time
docker compose logs -f <service-name>
```

**Common Causes**:
1. **Application crash**: Check logs for Python/Node errors
2. **Port conflict**: Another service using the port
3. **Missing environment variable**: Check `.env` file
4. **Out of memory**: Increase Docker memory limit

---

### Volume Permission Issues

**Symptoms**:
```
Permission denied when accessing /app/...
```

**Solution**:

**Mac/Windows**: Usually not an issue

**Linux**:
```bash
# Fix ownership
sudo chown -R $USER:$USER .

# Or run as root (not recommended for production)
docker compose exec -u root backend bash
```

---

### Cannot Delete Volume

**Symptoms**:
```
volume is in use - remove failed
```

**Solution**:
```bash
# Stop all containers
docker compose down

# Force remove volumes
docker compose down -v --remove-orphans

# Nuclear option (removes all unused volumes)
docker volume prune -f
```

---

### Slow Docker Performance (Mac)

**Symptoms**:
- Long build times
- Slow file system operations
- High CPU usage

**Solutions**:

1. **Increase Resources**:
   - Docker Desktop → Settings → Resources
   - CPUs: 4+
   - Memory: 8GB+

2. **Enable VirtioFS**:
   - Settings → General → Enable VirtioFS
   - Restart Docker Desktop

3. **Optimize Volume Mounts**:
   - Use `:delegated` or `:cached` flags
   ```yaml
   volumes:
     - ./backend:/app:delegated
   ```

4. **Exclude Node Modules**:
   ```yaml
   volumes:
     - ./frontend:/app
     - /app/node_modules  # Don't sync node_modules
   ```

---

## Database Issues

### Connection Refused

**Symptoms**:
```
psycopg.OperationalError: connection refused
```

**Diagnosis**:
```bash
# Check if PostgreSQL container is running
docker compose ps db

# Check if database is healthy
docker compose exec db pg_isready -U postgres

# Check logs
docker compose logs db
```

**Solutions**:

1. **Wait for Database to Initialize** (first run):
   ```bash
   # First startup takes 30-60 seconds
   docker compose logs -f db
   # Wait for: "database system is ready to accept connections"
   ```

2. **Check Network Connectivity**:
   ```bash
   # From backend container
   docker compose exec backend ping db
   ```

3. **Verify Environment Variables**:
   ```bash
   # Check backend has correct DB settings
   docker compose exec backend env | grep POSTGRES
   ```

---

### Password Authentication Failed

**Symptoms**:
```
FATAL: password authentication failed for user "postgres"
```

**Cause**: `.env` password changed after database volume was created

**Solution**:
```bash
# Remove old database volume
docker compose down -v

# Start fresh with new password
docker compose up -d
```

⚠️ **Warning**: This deletes all data!

**Production Alternative**:
```bash
# Connect to database
docker compose exec db psql -U postgres

# Change password
ALTER USER postgres PASSWORD 'new-password';
```

---

### Database Migrations Failed

**Symptoms**:
```
alembic.util.exc.CommandError: Can't locate revision identified by 'xxxx'
```

**Solutions**:

1. **Reset Migration History** (development only):
   ```bash
   # Remove migration history
   docker compose exec backend rm -rf /app/alembic/versions/*.py

   # Generate fresh migration
   docker compose exec backend alembic revision --autogenerate -m "initial"

   # Apply migration
   docker compose exec backend alembic upgrade head
   ```

2. **Sync Database State**:
   ```bash
   # Stamp current revision without running migrations
   docker compose exec backend alembic stamp head
   ```

---

### Database Disk Space Full

**Symptoms**:
```
ERROR: could not extend file: No space left on device
```

**Check Disk Usage**:
```bash
docker system df
docker volume ls
```

**Solutions**:

1. **Clean Up Docker**:
   ```bash
   # Remove unused containers, networks, images
   docker system prune -a

   # Remove unused volumes (careful!)
   docker volume prune
   ```

2. **Backup and Restore**:
   ```bash
   # Backup database
   docker compose exec db pg_dump -U postgres app > backup.sql

   # Remove old volume
   docker compose down -v

   # Start fresh
   docker compose up -d

   # Restore backup
   docker compose exec -T db psql -U postgres app < backup.sql
   ```

---

## Backend Issues

### Import Errors

**Symptoms**:
```python
ModuleNotFoundError: No module named 'fastapi'
```

**Solutions**:

1. **Rebuild Container**:
   ```bash
   docker compose build backend
   docker compose up -d backend
   ```

2. **Verify Dependencies Installed**:
   ```bash
   docker compose exec backend uv sync
   ```

3. **Check Python Path**:
   ```bash
   docker compose exec backend python -c "import sys; print(sys.path)"
   ```

---

### "changethis" Security Warnings

**Symptoms**:
```
UserWarning: The value of SECRET_KEY is "changethis"
```

**Solution**:

1. **Check `.env` File**:
   ```bash
   grep "SECRET_KEY" .env
   # Should NOT show "changethis"
   ```

2. **Check for Shell Environment Variables**:
   ```bash
   env | grep -E "(SECRET_KEY|POSTGRES_PASSWORD|FIRST_SUPERUSER_PASSWORD)"
   # These override .env file!
   ```

3. **Unset Shell Variables**:
   ```bash
   unset SECRET_KEY
   unset POSTGRES_PASSWORD
   unset FIRST_SUPERUSER_PASSWORD
   ```

4. **Restart Services**:
   ```bash
   docker compose down
   docker compose up -d
   ```

---

### API Returns 500 Error

**Symptoms**:
```json
{"detail": "Internal Server Error"}
```

**Diagnosis**:
```bash
# Check backend logs
docker compose logs backend | tail -100

# Look for Python tracebacks
docker compose logs backend | grep "Traceback"

# Check real-time
docker compose logs -f backend
```

**Common Causes**:
1. **Database connection failed** - Check DB logs
2. **Missing environment variable** - Check `.env`
3. **Validation error** - Check request payload
4. **Unhandled exception** - Fix code bug

---

### JWT Token Errors

**Symptoms**:
```json
{"detail": "Could not validate credentials"}
```

**Causes**:
1. **Token expired** - Login again
2. **SECRET_KEY changed** - Old tokens invalid
3. **Token format incorrect** - Check Authorization header

**Solution**:
```bash
# Test with fresh login
curl -X POST http://localhost:8000/api/v1/login/access-token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=your-password"
```

---

### Hot Reload Not Working

**Symptoms**:
- Change Python code
- No reload happens

**Solutions**:

1. **Verify Using `docker compose watch`**:
   ```bash
   docker compose watch
   # Not: docker compose up
   ```

2. **Check Volume Mount**:
   ```bash
   docker compose exec backend ls -la /app/app
   # Files should match your local directory
   ```

3. **Check Override File**:
   ```yaml
   # In docker-compose.override.yml
   backend:
     volumes:
       - ./backend:/app
   ```

4. **Manual Restart**:
   ```bash
   docker compose restart backend
   ```

---

## Frontend Issues

### Frontend Won't Load

**Symptoms**:
- Browser shows "Connection refused"
- http://localhost:5173 not accessible

**Diagnosis**:
```bash
# Check container status
docker compose ps frontend

# Check logs
docker compose logs frontend

# Check if port is bound
docker compose port frontend 80
```

**Solutions**:

1. **Wait for First Build** (first run):
   ```bash
   # Frontend build takes 2-5 minutes first time
   docker compose logs -f frontend
   # Wait for: "ready in XXX ms"
   ```

2. **Rebuild Frontend**:
   ```bash
   docker compose build frontend
   docker compose up -d frontend
   ```

3. **Clear Browser Cache**:
   - Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)

---

### React Hot Reload Not Working

**Symptoms**:
- Edit `.tsx` file
- Browser doesn't update

**Solutions**:

1. **Hard Refresh**: Cmd+Shift+R / Ctrl+Shift+R

2. **Check Volume Mount**:
   ```bash
   docker compose exec frontend ls /app/src
   ```

3. **Check Vite Config**:
   ```bash
   docker compose logs frontend | grep "watching for file changes"
   ```

4. **Restart Frontend**:
   ```bash
   docker compose restart frontend
   ```

---

### API Client Type Errors

**Symptoms**:
```typescript
Property 'xyz' does not exist on type...
```

**Cause**: Backend API changed, frontend client out of sync

**Solution**:
```bash
# Regenerate API client
./scripts/generate-client.sh

# Or manually:
# 1. Download OpenAPI spec
curl http://localhost:8000/api/v1/openapi.json > frontend/openapi.json

# 2. Generate client
cd frontend
npm run generate-client
```

---

### Build Errors

**Symptoms**:
```
Module not found: Can't resolve '@/components/...'
```

**Solutions**:

1. **Install Dependencies**:
   ```bash
   docker compose exec frontend npm install
   # Or rebuild
   docker compose build frontend
   ```

2. **Check Import Paths**:
   ```typescript
   // Use @ alias
   import { Button } from '@/components/ui/button'
   // Not relative paths
   ```

3. **Clear Node Modules**:
   ```bash
   docker compose down
   docker volume rm $(docker volume ls -q | grep node_modules)
   docker compose build frontend
   ```

---

## Network & Connectivity

### CORS Errors

**Symptoms** (in browser console):
```
Access to fetch at 'http://localhost:8000' from origin 'http://localhost:5173'
has been blocked by CORS policy
```

**Solution**:

Check `BACKEND_CORS_ORIGINS` in `.env`:
```env
# Development
BACKEND_CORS_ORIGINS="http://localhost,http://localhost:5173"

# Production
BACKEND_CORS_ORIGINS="https://dashboard.yourdomain.com,https://yourdomain.com"
```

Restart backend:
```bash
docker compose restart backend
```

---

### Cannot Reach Backend from Frontend

**Symptoms**:
- Frontend loads
- API calls fail

**Diagnosis**:
```bash
# From your browser console
fetch('http://localhost:8000/api/v1/utils/health-check/')

# From frontend container
docker compose exec frontend wget -O- http://backend:8000/api/v1/utils/health-check/
```

**Solutions**:

1. **Check Backend is Running**:
   ```bash
   docker compose ps backend
   curl http://localhost:8000/api/v1/utils/health-check/
   ```

2. **Check Network**:
   ```bash
   docker network ls
   # Inspect the default network (replace with your STACK_NAME from .env)
   docker network inspect ${STACK_NAME}_default
   ```

---

### SSL Certificate Issues (Production)

**Symptoms**:
```
Your connection is not private
NET::ERR_CERT_AUTHORITY_INVALID
```

**Solutions**:

1. **Check Traefik Logs**:
   ```bash
   docker compose -f docker-compose.traefik.yml logs
   ```

2. **Verify Email in Traefik Config**:
   - Must be a real email (not @example.com)

3. **Check DNS**:
   ```bash
   dig yourdomain.com
   dig api.yourdomain.com
   ```

4. **Manual Certificate Request**:
   ```bash
   # Check Traefik dashboard
   https://traefik.yourdomain.com
   ```

---

## Performance Issues

### Slow Page Load

**Diagnosis**:
```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:5173

# curl-format.txt:
time_namelookup:  %{time_namelookup}\n
time_connect:  %{time_connect}\n
time_starttransfer:  %{time_starttransfer}\n
time_total:  %{time_total}\n
```

**Solutions**:

1. **Database Query Optimization**:
   ```bash
   # Enable query logging
   docker compose exec db psql -U postgres -d app

   # Check slow queries
   SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
   ```

2. **Add Database Indexes**:
   ```python
   # In backend/app/models.py
   class User(SQLModel, table=True):
       email: str = Field(unique=True, index=True)  # Add index
   ```

3. **Enable Frontend Build Optimization**:
   ```bash
   # Use production build
   cd frontend
   npm run build
   ```

---

### High Memory Usage

**Diagnosis**:
```bash
# Check container stats
docker stats

# Check specific service (replace with your STACK_NAME from .env)
docker stats ${STACK_NAME}-backend-1
```

**Solutions**:

1. **Limit Container Memory**:
   ```yaml
   # In docker-compose.yml
   backend:
     deploy:
       resources:
         limits:
           memory: 512M
   ```

2. **Optimize Database Connections**:
   ```python
   # Reduce pool size in backend/app/core/db.py
   engine = create_engine(
       str(settings.SQLALCHEMY_DATABASE_URI),
       pool_size=5,  # Reduce from default
       max_overflow=10
   )
   ```

---

## Production Issues

### Service Unavailable

**Quick Checks**:
```bash
# Are containers running?
docker compose ps

# Any recent restarts?
docker compose ps --all

# Disk space?
df -h

# Memory?
free -h
```

---

### Cannot SSH to Server

**Solutions**:

1. **Check SSH Service**:
   ```bash
   # From server console (if available)
   systemctl status ssh
   ```

2. **Firewall**:
   ```bash
   ufw status
   ufw allow OpenSSH
   ```

3. **SSH Key Issues**:
   ```bash
   # Test connection
   ssh -vvv user@server

   # Check permissions
   chmod 600 ~/.ssh/id_rsa
   chmod 644 ~/.ssh/id_rsa.pub
   ```

---

### Out of Disk Space

**Diagnosis**:
```bash
df -h
docker system df
```

**Solutions**:

1. **Clean Docker**:
   ```bash
   docker system prune -a --volumes
   ```

2. **Clean Logs**:
   ```bash
   journalctl --vacuum-time=7d
   ```

3. **Remove Old Backups**:
   ```bash
   find /backups -mtime +30 -delete
   ```

---

## Getting More Help

### Enable Debug Logging

**Backend**:
```python
# In backend/app/main.py
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Frontend**:
```typescript
// In browser console
localStorage.debug = '*'
```

### Useful Commands

```bash
# Full system info
docker compose ps -a
docker compose logs --tail=100
docker system df
docker network ls

# Container inspection
docker compose exec backend env
docker compose exec backend ps aux
docker compose exec backend df -h

# Database inspection
docker compose exec db psql -U postgres -d app -c "\dt"
docker compose exec db psql -U postgres -d app -c "\du"
```

### Where to Get Help

1. **Check Documentation**:
   - [Getting Started](./getting-started.md)
   - [Architecture](../ARCHITECTURE.md)
   - [Deployment](./deployment-checklist.md)

2. **Community Resources**:
   - [FastAPI Discussions](https://github.com/tiangolo/fastapi/discussions)
   - [React Community](https://react.dev/community)
   - [Docker Forums](https://forums.docker.com/)

3. **Open an Issue**:
   - Provide error messages
   - Include relevant logs
   - List steps to reproduce
   - Specify environment (OS, Docker version, etc.)

---

## Emergency Procedures

### Complete Reset (Development Only)

⚠️ **Deletes all data!**

```bash
# Stop everything
docker compose down -v --remove-orphans

# Remove all project images
docker compose down --rmi all

# Clear Docker cache
docker builder prune -af

# Start fresh
docker compose watch
```

### Rollback (Production)

```bash
# 1. Stop current deployment
docker compose down

# 2. Checkout previous version
git checkout <previous-tag>

# 3. Restore database (if needed)
docker exec -i postgres psql -U postgres app < backup.sql

# 4. Start previous version
docker compose -f docker-compose.yml up -d

# 5. Verify
curl https://api.yourdomain.com/api/v1/utils/health-check/
```

---

**Remember**: When in doubt, check the logs first! 🔍

```bash
docker compose logs -f
```
