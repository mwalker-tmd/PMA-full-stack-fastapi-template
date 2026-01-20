# Continuous Integration (CI) and Continuous Deployment (CD)

This project includes automated testing and deployment workflows using GitHub Actions.

## Table of Contents

- [Overview](#overview)
- [Quick Start - Setup GitHub Secrets](#quick-start---setup-github-secrets)
- [CI Workflows](#ci-workflows)
- [Environment Variables](#environment-variables)
- [Running Workflows](#running-workflows)
- [Troubleshooting](#troubleshooting)
- [CD Workflows](#cd-workflows)

---

## Quick Start - Setup GitHub Secrets

**Before CI workflows can run, you must configure GitHub Secrets.**

See the complete guide: **[GitHub Secrets Setup](./github-secrets-setup.md)**

**Quick setup**:
1. Go to your repo's **Settings → Secrets and variables → Actions**
2. Add **3 Secrets** and **20 Variables** (see [setup guide](./github-secrets-setup.md) for values):
   - **Secrets** (3): `SECRET_KEY`, `FIRST_SUPERUSER_PASSWORD`, `POSTGRES_PASSWORD`
   - **Variables** (20): `PROJECT_NAME`, `STACK_NAME`, `DOMAIN`, and 17 more
3. Push code - workflows will run automatically

**Why Secrets AND Variables?**
- **Secrets**: Encrypted, for sensitive data (passwords, keys)
- **Variables**: Visible, for non-sensitive config (URLs, names, ports)

This follows the **principle of least privilege** and industry best practices.

---

## Overview

### What is CI/CD?

**Continuous Integration (CI)**:
- Automatically runs tests when you push code or create a pull request
- Runs on GitHub's servers (cloud runners)
- Does NOT affect your local Docker Desktop or development environment
- Catches bugs before they reach production

**Continuous Deployment (CD)**:
- Automatically deploys your application to staging or production servers
- Runs when you push to main branch or create release tags
- Requires additional configuration (server access, secrets, etc.)
- Not covered in detail here - see [Deployment Guide](../deployment.md)

---

## CI Workflows

The project includes three main CI workflows that run on every pull request:

### 1. Backend Tests (`test-backend.yml`)

**What it does**:
- Starts PostgreSQL database and mail server
- Runs database migrations
- Executes all backend unit tests
- Generates coverage report (requires 90%+ coverage)

**When it runs**:
- On push to `main` branch
- On pull request open or sync

**Duration**: ~2-3 minutes

### 2. Playwright E2E Tests (`playwright.yml`)

**What it does**:
- Builds full Docker Compose stack (frontend, backend, database)
- Runs end-to-end tests in real browsers
- Tests user flows (login, CRUD operations, etc.)
- Runs tests in parallel across 4 shards for speed

**When it runs**:
- On push to `main` branch
- On pull request open or sync
- Only if relevant files changed (backend, frontend, docker configs)

**Duration**: ~5-8 minutes

### 3. Docker Compose Tests (`test-docker-compose.yml`)

**What it does**:
- Builds all Docker images
- Starts the full stack
- Verifies backend and frontend are accessible
- Health checks all services

**When it runs**:
- On push to `main` branch
- On pull request open or sync

**Duration**: ~3-4 minutes

### 4. Pre-commit Checks (`pre-commit.yml`)

**What it does**:
- Runs code formatters (ruff, biome)
- Runs linters
- Auto-formats code and commits changes (if you have PRE_COMMIT secret)
- Otherwise reports formatting issues

**When it runs**:
- On pull request open or sync

**Duration**: ~2-3 minutes

---

## Environment Variables

### Test Environment Variables

All CI workflows use **GitHub Secrets and Variables** for configuration. This follows industry best practices for CI/CD pipelines.

**How it works**:
- **Local development**: Docker Compose automatically loads `.env` file (gitignored)
- **CI (GitHub Actions)**: No `.env` file exists; Docker Compose uses environment variables from workflow `env:` section
- **Production**: Same pattern - no `.env` file; environment variables come from platform secrets management (Kubernetes Secrets, AWS Secrets Manager, etc.)

**Database connection per environment**:
- **Docker services** (prestart, backend): Always use `POSTGRES_SERVER=db` (Docker network hostname)
- **Host-based tests** (CI test-backend workflow): Use `POSTGRES_SERVER=localhost` (exposed port 5432)
- **Production**: Use actual database endpoint from secrets manager

This is the professional 12-factor app approach: configuration comes from the environment, not from files in the codebase.

**Required secrets** (configured in GitHub Settings):
```yaml
env:
  SECRET_KEY: ${{ secrets.SECRET_KEY }}
  FIRST_SUPERUSER: ${{ secrets.FIRST_SUPERUSER }}
  FIRST_SUPERUSER_PASSWORD: ${{ secrets.FIRST_SUPERUSER_PASSWORD }}
  POSTGRES_SERVER: ${{ secrets.POSTGRES_SERVER }}
  POSTGRES_USER: ${{ secrets.POSTGRES_USER }}
  POSTGRES_PASSWORD: ${{ secrets.POSTGRES_PASSWORD }}
  POSTGRES_DB: ${{ secrets.POSTGRES_DB }}
```

### Why use GitHub Secrets?

1. **Industry standard**: How professional teams manage CI/CD configuration
2. **Separation of concerns**: Configuration separate from code
3. **Security**: Secrets never exposed in code or logs
4. **Reusable**: Same pattern for staging and production
5. **Educational**: Students learn proper secrets management

### Local vs CI Environment Variables

| Environment | Secret Key | Password | Where Defined |
|-------------|-----------|----------|---------------|
| **Local Development** | Your `.env` file | Your `.env` file | `.env` (gitignored) |
| **CI/GitHub Actions** | GitHub Secrets | GitHub Secrets | Settings → Secrets and variables |
| **Production** | Server environment | Server environment | Server `.env` or secrets manager |

### Do I need to set GitHub Secrets?

**For CI tests**: ✅ **Yes!** You must configure GitHub Secrets for workflows to run.

See the complete setup guide: **[GitHub Secrets Setup](./github-secrets-setup.md)**

**For deployment (CD)**: ✅ You'll use additional production secrets (see [Deployment Guide](../deployment.md)).

---

## Running Workflows

### Viewing Workflow Runs

1. Go to your GitHub repository
2. Click the **Actions** tab
3. See all workflow runs and their status

### Re-running Failed Workflows

If a workflow fails:

1. Click on the failed workflow run
2. Review the error logs
3. Fix the issue locally
4. Push your fix
5. Workflow will automatically re-run

Or manually re-run:
1. Click **Re-run all jobs** button

### Running Workflows Locally

You can run the same tests locally before pushing:

```bash
# Backend tests (same as CI)
docker compose exec backend bash /app/scripts/test.sh

# E2E tests (same as CI)
docker compose run --rm playwright npx playwright test

# Docker Compose stack test
docker compose up -d --wait backend frontend
curl http://localhost:8000/api/v1/utils/health-check
curl http://localhost:5173
docker compose down

# Pre-commit checks
cd backend
uv run prek run --all-files
```

---

## Troubleshooting

### Common CI Failures

#### "Required variable POSTGRES_PASSWORD is missing"

**Cause**: Workflow file missing environment variables

**Fix**: Ensure workflow has `env:` section at job level:
```yaml
jobs:
  test-backend:
    runs-on: ubuntu-latest
    env:
      SECRET_KEY: "test-secret-key-for-ci"
      FIRST_SUPERUSER_PASSWORD: "test-password-for-ci"
      POSTGRES_PASSWORD: "test-db-password-for-ci"
    steps:
      # ...
```

#### "biome: not found" in pre-commit workflow

**Cause**: Biome tool not installed in CI environment

**Fix**: Add installation step (already done in this template):
```yaml
- name: Install biome (JavaScript/TypeScript linter)
  run: npm install --global @biomejs/biome
```

#### Tests pass locally but fail in CI

**Possible causes**:
1. Different environment variables between local and CI
2. Timing issues (CI runners can be slower)
3. Database state differences
4. Missing dependencies in CI

**Debugging**:
1. Check workflow logs in GitHub Actions tab
2. Compare local `.env` with CI env vars
3. Try running with same env vars locally
4. Enable debug mode in workflow (add `ACTIONS_STEP_DEBUG: true`)

#### Coverage below 90%

**Error**: `coverage report --fail-under=90` fails

**Fix**: Add tests to increase coverage or lower threshold in `test-backend.yml`:
```yaml
- name: Coverage report
  run: uv run coverage report --fail-under=80  # Lower from 90 to 80
  working-directory: backend
```

---

## CD Workflows

This template does NOT include CD workflows by default. For production deployment:

1. See [Deployment Guide](../deployment.md)
2. See [Deployment Checklist](./deployment-checklist.md)
3. Consider using:
   - GitHub Actions with self-hosted runners
   - Platform-as-a-Service (Heroku, Railway, Render)
   - Container platforms (AWS ECS, Google Cloud Run)

### Why no CD in template?

- Deployment is highly environment-specific
- Requires server access and production secrets
- Students/users should understand deployment before automating it
- Template users will have different hosting requirements

---

## Workflow File Locations

All workflows are in `.github/workflows/`:

```
.github/workflows/
├── test-backend.yml          # Backend unit tests
├── playwright.yml            # E2E tests
├── test-docker-compose.yml   # Stack integration tests
├── pre-commit.yml            # Code formatting/linting
└── generate-client.yml       # API client generation (optional)
```

---

## Best Practices

### For Contributors

1. **Always run tests locally first** before pushing
2. **Check workflow status** after pushing
3. **Fix CI failures promptly** - don't merge with failing tests
4. **Review coverage reports** - aim for 90%+ coverage

### For Maintainers

1. **Keep workflow dependencies updated** (actions versions)
2. **Monitor workflow run times** - optimize slow tests
3. **Review failed workflows** - may indicate real bugs
4. **Update test env vars** if you add new required variables

### For Students/Learners

1. **Understand what each workflow does** before modifying
2. **Read workflow logs** when failures occur - they're educational!
3. **Don't skip CI** - it catches bugs early
4. **Ask questions** if workflow behavior is unclear

---

## Modifying Workflows

### Adding a new required environment variable

If you add a new required environment variable to the backend:

1. **Update all three test workflows**:
   - `test-backend.yml`
   - `playwright.yml`
   - `test-docker-compose.yml`

2. **Add to the `env:` section** at the job level:
   ```yaml
   env:
     SECRET_KEY: "test-secret-key-for-ci"
     FIRST_SUPERUSER_PASSWORD: "test-password-for-ci"
     POSTGRES_PASSWORD: "test-db-password-for-ci"
     YOUR_NEW_VAR: "test-value-for-ci"  # Add here
   ```

3. **Test locally** with the same test value
4. **Update this documentation** to reflect the new variable

### Disabling a workflow

To temporarily disable a workflow without deleting it:

1. Add condition to top of workflow:
   ```yaml
   name: Test Backend

   on:
     push:
       branches:
         - main

   jobs:
     test-backend:
       if: false  # Disable workflow
       runs-on: ubuntu-latest
       # ...
   ```

2. Or rename the file to `*.yml.disabled`

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Compose in CI](https://docs.docker.com/compose/ci/)
- [Playwright CI Guide](https://playwright.dev/docs/ci)
- [pytest Documentation](https://docs.pytest.org/)

---

**Last Updated**: January 2026

For questions about CI/CD setup, see [Troubleshooting Guide](./troubleshooting.md) or open a GitHub Discussion.
