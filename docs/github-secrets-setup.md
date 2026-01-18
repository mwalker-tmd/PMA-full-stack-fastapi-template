# GitHub Secrets Setup for CI/CD

This document explains how to configure GitHub Secrets for the CI/CD workflows to run successfully.

## Why GitHub Secrets?

GitHub Secrets allow you to store sensitive configuration values (like passwords and API keys) securely. The CI/CD workflows in this template use secrets for:

- Database credentials
- Application secrets
- Test user credentials

This follows **industry best practices** for secrets management in CI/CD pipelines.

---

## Required Secrets

You need to configure the following secrets in your GitHub repository:

| Secret Name | Description | Example Value for CI |
|-------------|-------------|---------------------|
| `PROJECT_NAME` | Project display name | `Test Project` |
| `STACK_NAME` | Docker Compose stack name (no spaces) | `test-stack` |
| `DOMAIN` | Domain name for routing | `localhost` |
| `SECRET_KEY` | Application secret key for JWT tokens | `test-secret-key-for-ci-only` |
| `FIRST_SUPERUSER` | Initial admin user email | `admin@example.com` |
| `FIRST_SUPERUSER_PASSWORD` | Initial admin user password | `test-password-for-ci-only` |
| `POSTGRES_SERVER` | Database hostname | `db` |
| `POSTGRES_USER` | Database username | `postgres` |
| `POSTGRES_PASSWORD` | Database password | `test-db-password-for-ci-only` |
| `POSTGRES_DB` | Database name | `app` |

**Important**: These are for **CI testing only**. Production secrets should be different and stored securely on your deployment server or cloud provider's secrets manager.

---

## How to Add Secrets to GitHub

### Step 1: Navigate to Repository Settings

1. Go to your GitHub repository
2. Click on **Settings** (top navigation)
3. In the left sidebar, click **Secrets and variables** → **Actions**

### Step 2: Add Each Secret

For each secret in the table above:

1. Click **"New repository secret"**
2. Enter the **Name** (exactly as shown in table, case-sensitive)
3. Enter the **Value** (use the suggested CI values or generate secure ones)
4. Click **"Add secret"**

### Step 3: Verify Secrets

After adding all secrets, you should see 10 secrets listed:
- PROJECT_NAME
- STACK_NAME
- DOMAIN
- SECRET_KEY
- FIRST_SUPERUSER
- FIRST_SUPERUSER_PASSWORD
- POSTGRES_SERVER
- POSTGRES_USER
- POSTGRES_PASSWORD
- POSTGRES_DB

---

## Recommended Values for CI Testing

For continuous integration testing, you can use these test-safe values:

```bash
PROJECT_NAME=Test Project
STACK_NAME=test-stack
DOMAIN=localhost
SECRET_KEY=test-secret-key-for-ci-only
FIRST_SUPERUSER=admin@example.com
FIRST_SUPERUSER_PASSWORD=test-password-for-ci-only
POSTGRES_SERVER=db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=test-db-password-for-ci-only
POSTGRES_DB=app
```

**Note**: These are safe for CI because:
- They're only used in ephemeral GitHub Actions runners
- They're never exposed in production
- They're reset with each test run
- They're not production credentials

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

## Workflows That Use These Secrets

The following workflows require these secrets:

1. **Test Backend** (`.github/workflows/test-backend.yml`)
   - Runs backend unit tests
   - Requires database credentials

2. **Playwright Tests** (`.github/workflows/playwright.yml`)
   - Runs end-to-end tests
   - Requires full application stack

3. **Test Docker Compose** (`.github/workflows/test-docker-compose.yml`)
   - Tests docker-compose configuration
   - Validates stack can build and start

---

## Troubleshooting

### "Secret not found" Error

**Symptom**: Workflow fails with environment variable not set

**Solution**:
1. Verify the secret name matches exactly (case-sensitive)
2. Check you added it to **Actions secrets** (not Environment secrets)
3. Re-run the workflow after adding secrets

### Workflows Still Failing After Adding Secrets

**Possible causes**:
1. Secret name typo (check spelling and case)
2. Secret value has trailing spaces (re-add without spaces)
3. Old workflow run cached (click "Re-run all jobs")

**Debug steps**:
1. Go to Actions tab
2. Click failed workflow run
3. Click on failed job
4. Expand the step that failed
5. Look for "required variable X is missing" errors

### Testing Locally vs CI

**Local development** uses `.env` file with your values:
```bash
# .env (local only, gitignored)
SECRET_KEY=your-local-secret
POSTGRES_PASSWORD=your-local-password
# ... etc
```

**CI workflows** use GitHub Secrets (configured above)

**Production deployment** uses server environment variables or cloud secrets manager

---

## Security Best Practices

### ✅ DO:
- Use different secrets for CI, staging, and production
- Rotate secrets periodically
- Use GitHub Secrets for all sensitive values
- Document which secrets are required

### ❌ DON'T:
- Hardcode secrets in workflow files
- Commit secrets to git
- Use production credentials in CI
- Share secrets in plain text

---

## Next Steps

After configuring secrets:

1. ✅ Push your code to GitHub
2. ✅ Workflows will automatically run
3. ✅ Check the Actions tab to verify tests pass
4. ✅ Fix any remaining issues

For more information:
- [CI/CD Guide](./ci-cd.md)
- [Troubleshooting](./troubleshooting.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

## For Template Users

If you're using this as a template for a new project:

1. Create your repository from this template
2. Follow the steps above to add GitHub Secrets
3. Update secret values for your project
4. Your CI/CD will work automatically

That's it! The workflows are already configured to use these secrets.

---

**Last Updated**: January 2026

For questions about secrets setup, see [Troubleshooting Guide](./troubleshooting.md) or open a GitHub Discussion.
