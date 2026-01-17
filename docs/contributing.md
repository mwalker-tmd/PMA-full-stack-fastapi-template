# Contributing Guide

Thank you for your interest in contributing to this Full Stack FastAPI project! This guide will help you get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Review Process](#review-process)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of experience level, gender identity, sexual orientation, disability, appearance, race, ethnicity, age, religion, or nationality.

### Expected Behavior

- Be respectful and considerate
- Welcome newcomers and help them learn
- Focus on what is best for the community
- Show empathy towards others
- Accept constructive criticism gracefully

### Unacceptable Behavior

- Harassment, discrimination, or intimidation
- Trolling or insulting comments
- Publishing others' private information
- Any conduct that would be inappropriate in a professional setting

## Getting Started

### Prerequisites

Before contributing, make sure you have:

- [ ] Read the [Getting Started](./getting-started.md) guide
- [ ] Set up your local development environment
- [ ] Read the [Architecture](../ARCHITECTURE.md) documentation
- [ ] Familiarized yourself with the codebase

### Finding Issues to Work On

1. **Check Open Issues**: Look for issues labeled:
   - `good first issue` - Great for newcomers
   - `help wanted` - Need community assistance
   - `bug` - Something isn't working
   - `enhancement` - New feature requests

2. **Ask Questions**: Comment on the issue to ask questions or clarify requirements

3. **Claim the Issue**: Comment "I'd like to work on this" to avoid duplicate work

### Setting Up Your Fork

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
cd YOUR-REPO-NAME

# 3. Add upstream remote
git remote add upstream https://github.com/ORIGINAL-OWNER/ORIGINAL-REPO.git

# 4. Verify remotes
git remote -v

# 5. Create a branch for your work
git checkout -b feature/your-feature-name
```

## Development Workflow

### 1. Sync with Upstream

Always start with the latest code:

```bash
# Fetch latest changes
git fetch upstream

# Merge into your branch
git merge upstream/main

# Or rebase (preferred)
git rebase upstream/main
```

### 2. Make Your Changes

**Branch Naming Convention**:
- Features: `feature/description`
- Bug fixes: `fix/description`
- Documentation: `docs/description`
- Refactoring: `refactor/description`

**Examples**:
- `feature/add-user-profile`
- `fix/login-validation-error`
- `docs/update-deployment-guide`

### 3. Test Your Changes

**Before committing**, ensure:

```bash
# Backend tests pass
docker compose exec backend bash /app/scripts/test.sh

# Frontend tests pass (if applicable)
cd frontend && npm run test

# E2E tests pass (if applicable)
docker compose run --rm playwright npx playwright test

# Linting passes
cd backend && uv run prek run --all-files
cd frontend && npm run lint
```

### 4. Commit Your Changes

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring (no feature change)
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples**:

```bash
git commit -m "feat(auth): add password reset functionality"
git commit -m "fix(api): handle null values in user endpoint"
git commit -m "docs(readme): update installation instructions"
```

**Good Commit Message**:
```
feat(items): add bulk delete functionality

Add ability to delete multiple items at once through new
/api/v1/items/bulk-delete endpoint. Includes:
- New API endpoint
- Frontend UI for multi-select
- Tests for bulk operations

Closes #123
```

### 5. Push Your Changes

```bash
git push origin feature/your-feature-name
```

## Code Standards

### Backend (Python/FastAPI)

**Style Guide**: Follow [PEP 8](https://pep8.org/)

**Tools**:
- Formatting: `ruff format`
- Linting: `ruff check`
- Type checking: Use Python type hints

**Example**:

```python
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session

router = APIRouter()


@router.get("/users/{user_id}")
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> User:
    """
    Get user by ID.

    Args:
        user_id: The user's ID
        db: Database session
        current_user: Authenticated user

    Returns:
        User object

    Raises:
        HTTPException: If user not found
    """
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
```

**Best Practices**:
- Use type hints for all function parameters and returns
- Add docstrings for public functions
- Keep functions small and focused (< 50 lines)
- Use meaningful variable names
- Handle errors gracefully
- Write tests for new functionality

### Frontend (TypeScript/React)

**Style Guide**: Follow [Airbnb React/JSX Style Guide](https://github.com/airbnb/javascript/tree/master/react)

**Tools**:
- Formatting: Prettier (via `npm run format`)
- Linting: ESLint (via `npm run lint`)
- Type checking: TypeScript

**Example**:

```typescript
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { UsersService } from '@/client'

interface UserListProps {
  limit?: number
}

export function UserList({ limit = 10 }: UserListProps) {
  const [page, setPage] = useState(1)

  const { data, isLoading, error } = useQuery({
    queryKey: ['users', page],
    queryFn: () => UsersService.readUsers({ skip: (page - 1) * limit, limit }),
  })

  if (isLoading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>

  return (
    <div>
      {data?.data.map((user) => (
        <div key={user.id}>{user.email}</div>
      ))}
      <Button onClick={() => setPage(page + 1)}>Next</Button>
    </div>
  )
}
```

**Best Practices**:
- Use TypeScript for all new files
- Prefer functional components with hooks
- Extract reusable logic into custom hooks
- Keep components small (< 200 lines)
- Use proper prop types
- Accessibility: Add ARIA labels where needed

### Database Migrations

When changing models:

```bash
# 1. Modify models in backend/app/models.py

# 2. Generate migration
docker compose exec backend alembic revision --autogenerate -m "Add user profile fields"

# 3. Review the generated migration file

# 4. Test migration
docker compose exec backend alembic upgrade head

# 5. Test rollback
docker compose exec backend alembic downgrade -1
docker compose exec backend alembic upgrade head

# 6. Commit migration file
git add backend/app/alembic/versions/*.py
```

## Testing Requirements

### Backend Tests

All new backend features must include tests:

```python
# tests/api/routes/test_users.py
from fastapi.testclient import TestClient
from sqlmodel import Session

def test_create_user(client: TestClient, db: Session):
    """Test creating a new user."""
    response = client.post(
        "/api/v1/users/",
        json={
            "email": "test@example.com",
            "password": "securepassword123",
            "full_name": "Test User",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "id" in data
```

**Coverage Requirements**:
- New code: 80%+ coverage
- Critical paths (auth, payments): 95%+ coverage

### Frontend Tests

Test user-facing functionality:

```typescript
// tests/e2e/login.spec.ts
import { test, expect } from '@playwright/test'

test('user can log in', async ({ page }) => {
  await page.goto('http://localhost:5173')
  await page.click('text=Log In')

  await page.fill('input[name="email"]', 'admin@example.com')
  await page.fill('input[name="password"]', 'changethis')
  await page.click('button[type="submit"]')

  await expect(page).toHaveURL('http://localhost:5173/dashboard')
  await expect(page.locator('text=Welcome')).toBeVisible()
})
```

### Running Tests Locally

```bash
# Backend unit tests
docker compose exec backend pytest tests/

# Backend tests with coverage
docker compose exec backend bash /app/scripts/test.sh

# Frontend E2E tests
docker compose run --rm playwright npx playwright test

# Frontend unit tests (if added)
cd frontend && npm run test
```

## Documentation

### When to Update Documentation

Update docs when you:
- Add a new feature
- Change existing behavior
- Add new environment variables
- Modify API endpoints
- Change deployment process

### Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Project overview, quick start |
| `docs/getting-started.md` | Detailed setup guide |
| `docs/deployment-checklist.md` | Production deployment |
| `docs/troubleshooting.md` | Common issues |
| `ARCHITECTURE.md` | System design |
| `backend/README.md` | Backend-specific docs |
| `frontend/README.md` | Frontend-specific docs |

### API Documentation

FastAPI auto-generates API docs, but add descriptions:

```python
@router.post(
    "/users/",
    response_model=UserPublic,
    summary="Create a new user",
    description="Create a new user with the provided information. "
                "Email must be unique across the system.",
    responses={
        200: {"description": "User created successfully"},
        400: {"description": "Invalid input or email already exists"},
    },
)
def create_user(user_in: UserCreate, db: Session = Depends(get_db)):
    """Create new user."""
    ...
```

## Submitting Changes

### Creating a Pull Request

1. **Push to Your Fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open PR on GitHub**:
   - Go to the original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill in the PR template

### PR Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Related Issues
Closes #123

## Changes Made
- Added X feature
- Fixed Y bug
- Updated Z documentation

## Testing Done
- [ ] Added unit tests
- [ ] Added integration tests
- [ ] Manual testing completed
- [ ] All tests pass locally

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated
- [ ] All tests pass
```

### PR Best Practices

- **Keep PRs Small**: < 400 lines changed
- **Single Purpose**: One feature/fix per PR
- **Clear Description**: Explain what and why
- **Link Issues**: Use "Closes #123"
- **Add Screenshots**: For UI changes
- **Request Review**: Tag relevant reviewers

## Review Process

### What Reviewers Look For

1. **Code Quality**:
   - Follows style guidelines
   - Well-structured and readable
   - No unnecessary complexity

2. **Functionality**:
   - Works as described
   - Handles edge cases
   - No breaking changes (unless intended)

3. **Tests**:
   - Adequate test coverage
   - Tests are meaningful
   - All tests pass

4. **Documentation**:
   - Code is documented
   - User-facing docs updated
   - API docs accurate

### Responding to Feedback

- Be open to suggestions
- Ask questions if unclear
- Make requested changes
- Push updates to same branch
- Re-request review when ready

### After Approval

1. **Rebase if Needed**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   git push --force-with-lease origin feature/your-feature
   ```

2. **Merge**: Maintainer will merge your PR

3. **Clean Up**:
   ```bash
   git checkout main
   git pull upstream main
   git branch -d feature/your-feature
   ```

## Recognition

Contributors will be:
- Listed in `CONTRIBUTORS.md`
- Mentioned in release notes
- Invited to team discussions (for regular contributors)

## Questions?

- **General Questions**: Open a GitHub Discussion
- **Bug Reports**: Open a GitHub Issue
- **Security Issues**: Email security@yourdomain.com (private)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing! 🎉

Your efforts help make this project better for everyone.
