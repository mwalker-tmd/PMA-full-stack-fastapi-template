# GitHub Secrets and Variables Setup for CI/CD

This document explains how to configure GitHub Secrets and Variables for the CI/CD workflows to run successfully.

## Why Separate Secrets and Variables?

GitHub provides two distinct features for configuration management, following security best practices:

### Repository Secrets (Sensitive Data)
- **Encrypted** and never visible in logs
- Cannot be viewed after creation
- Used for: passwords, API keys, tokens, private keys

### Repository Variables (Non-Sensitive Configuration)
- **Visible** in logs and can be viewed/edited
- Used for: URLs, names, ports, environment settings
- Easy to update without security concerns

This separation follows the **principle of least privilege** and makes configuration management clearer and safer.

---

## Required Configuration

### Repository Secrets (3 items)

**Path**: Settings → Secrets and variables → Actions → **Secrets** tab

| Secret Name | Description | Example Value for CI |
|-------------|-------------|---------------------|
| `SECRET_KEY` | Application secret key for JWT tokens | `test-secret-key-for-ci-only` |
| `FIRST_SUPERUSER_PASSWORD` | Initial admin user password | `test-password-for-ci-only` |
| `POSTGRES_PASSWORD` | Database password | `test-db-password-for-ci-only` |

### Repository Variables (20 items)

**Path**: Settings → Secrets and variables → Actions → **Variables** tab

| Variable Name | Description | Example Value for CI |
|---------------|-------------|---------------------|
| `PROJECT_NAME` | Project display name | `Test Project` |
| `STACK_NAME` | Docker Compose stack name (no spaces) | `test-stack` |
| `DOMAIN` | Domain name for routing | `localhost` |
| `ENVIRONMENT` | Environment type | `local` |
| `FRONTEND_HOST` | Frontend URL for backend to generate links | `http://localhost:5173` |
| `BACKEND_CORS_ORIGINS` | Allowed CORS origins (comma-separated) | `http://localhost,http://localhost:5173` |
| `FIRST_SUPERUSER` | Initial admin user email | `admin@example.com` |
| `POSTGRES_SERVER` | Database hostname | `db` |
| `POSTGRES_PORT` | Database port | `5432` |
| `POSTGRES_USER` | Database username | `postgres` |
| `POSTGRES_DB` | Database name | `app` |
| `DOCKER_IMAGE_BACKEND` | Backend Docker image name | `backend` |
| `DOCKER_IMAGE_FRONTEND` | Frontend Docker image name | `frontend` |
| `TAG` | Docker image tag | `latest` |
| `SMTP_HOST` | SMTP server host (dummy for CI) | `localhost` |
| `SMTP_USER` | SMTP username (dummy for CI) | `noreply@example.com` |
| `SMTP_PASSWORD` | SMTP password (dummy for CI) | `not-used-in-ci` |
| `EMAILS_FROM_EMAIL` | Email sender address | `info@example.com` |
| `SMTP_TLS` | Use TLS for SMTP | `True` |
| `SMTP_SSL` | Use SSL for SMTP | `False` |
| `SMTP_PORT` | SMTP port | `587` |
| `SENTRY_DSN` | Sentry error tracking DSN (dummy for CI) | `https://examplePublicKey@o0.ingest.sentry.io/0` |

---

## How to Add Secrets

### Step 1: Navigate to Secrets

1. Go to your GitHub repository
2. Click on **Settings** (top navigation)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click the **"Secrets"** tab

### Step 2: Add Each Secret

For each of the 3 secrets listed above:

1. Click **"New repository secret"**
2. Enter the **Name** (exactly as shown in table, case-sensitive)
3. Enter the **Value** (use the suggested CI values or generate secure ones)
4. Click **"Add secret"**

### Step 3: Verify Secrets

After adding all secrets, you should see 3 secrets listed:
- `SECRET_KEY`
- `FIRST_SUPERUSER_PASSWORD`
- `POSTGRES_PASSWORD`

---

## How to Add Variables

### Step 1: Navigate to Variables

1. In the same **Secrets and variables → Actions** page
2. Click the **"Variables"** tab (next to "Secrets")

### Step 2: Add Each Variable

For each of the 20 variables listed above:

1. Click **"New repository variable"**
2. Enter the **Name** (exactly as shown in table, case-sensitive)
3. Enter the **Value** (use the suggested CI values from the table)
4. Click **"Add variable"**

### Step 3: Verify Variables

After adding all variables, you should see 20 variables listed.

**Tip**: Variables are visible and editable, so you can easily verify values after creation.

---

## Recommended Values for CI Testing

### Secrets (Copy These Values)

```bash
# Generate secure random values or use these test-safe values:
SECRET_KEY=test-secret-key-for-ci-only
FIRST_SUPERUSER_PASSWORD=test-password-for-ci-only
POSTGRES_PASSWORD=test-db-password-for-ci-only
```

### Variables (Copy These Values)

```bash
PROJECT_NAME=Test Project
STACK_NAME=test-stack
DOMAIN=localhost
ENVIRONMENT=local
FRONTEND_HOST=http://localhost:5173
BACKEND_CORS_ORIGINS=http://localhost,http://localhost:5173
FIRST_SUPERUSER=admin@example.com
POSTGRES_SERVER=db
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_DB=app
DOCKER_IMAGE_BACKEND=backend
DOCKER_IMAGE_FRONTEND=frontend
TAG=latest
SMTP_HOST=localhost
SMTP_USER=noreply@example.com
SMTP_PASSWORD=not-used-in-ci
EMAILS_FROM_EMAIL=info@example.com
SMTP_TLS=True
SMTP_SSL=False
SMTP_PORT=587
SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
```

**Note**: These are safe dummy/test values for CI. SMTP settings won't send real emails (tests mock email sending), and Sentry is disabled in non-production environments.

---

## Why These Values Are Safe for CI

**Secrets**:
- Only used in ephemeral GitHub Actions runners
- Never exposed in production
- Reset with each test run
- Not production credentials

**Variables**:
- Non-sensitive configuration
- Appropriate for test environment
- Can be viewed in logs (which is fine - they're not secrets!)
- Easily updated as needed

---

## Generating Secure Secrets (Optional)

If you prefer to use secure random values even for CI:

```bash
# Generate a secure SECRET_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Generate a secure password
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Copy the output and use it as the secret value in GitHub.

---

## Workflows That Use These Configurations

The following workflows require these secrets and variables:

1. **Test Backend** (`.github/workflows/test-backend.yml`)
   - Runs backend unit tests
   - Requires all database and application config

2. **Playwright Tests** (`.github/workflows/playwright.yml`)
   - Runs end-to-end tests
   - Requires full application stack configuration

3. **Test Docker Compose** (`.github/workflows/test-docker-compose.yml`)
   - Tests docker-compose configuration
   - Validates stack can build and start

---

## Troubleshooting

### "Secret not found" or "Variable not found" Error

**Symptom**: Workflow fails with environment variable not set

**Solution**:
1. Verify the name matches exactly (case-sensitive)
2. Check you added it to the correct tab (Secrets vs Variables)
3. Ensure it's a **repository** secret/variable (not environment)
4. Re-run the workflow after adding

### How to Update Values

**Secrets**: Must delete and recreate (cannot edit)
**Variables**: Click pencil icon to edit value directly

### Testing Locally vs CI

**Local development** uses `.env` file:
```bash
# .env (local only, gitignored)
SECRET_KEY=your-local-secret
# ... etc
```

**CI workflows** use GitHub Secrets + Variables (configured above)

**Production deployment** uses server environment or cloud secrets manager

---

## Production Deployment Notes

**For production**, you'll use the same pattern but with different values:

- **Secrets**: Use strong, randomly generated values
- **Variables**: Use production URLs, domains, and configuration
- **Storage**: Consider using cloud provider secrets managers:
  - AWS: Secrets Manager, Systems Manager Parameter Store
  - Google Cloud: Secret Manager
  - Azure: Key Vault
  - Kubernetes: Secrets and ConfigMaps

---

## Security Best Practices

### ✅ DO:
- Use GitHub Secrets for all passwords, keys, and tokens
- Use GitHub Variables for non-sensitive configuration
- Rotate secrets periodically
- Use different values for dev, staging, and production
- Document what each secret/variable is for

### ❌ DON'T:
- Put secrets in Variables (they're visible!)
- Hardcode secrets in workflow files
- Commit secrets to git
- Use production credentials in CI
- Share secrets in plain text (use secure sharing tools)

---

## Next Steps

After configuring secrets and variables:

1. ✅ Verify all 3 secrets are added
2. ✅ Verify all 20 variables are added
3. ✅ Push your code to GitHub
4. ✅ Workflows will automatically run
5. ✅ Check the Actions tab to verify tests pass

For more information:
- [CI/CD Guide](./ci-cd.md)
- [Troubleshooting](./troubleshooting.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Variables Documentation](https://docs.github.com/en/actions/learn-github-actions/variables)

---

## For Template Users

If you're using this as a template for a new project:

1. Create your repository from this template
2. Follow the steps above to add 3 Secrets
3. Follow the steps above to add 20 Variables
4. Update values for your project as needed
5. Your CI/CD will work automatically

That's it! This is the professional, industry-standard approach to configuration management.

---

**Last Updated**: January 2026

For questions about setup, see [Troubleshooting Guide](./troubleshooting.md) or open a GitHub Discussion.
