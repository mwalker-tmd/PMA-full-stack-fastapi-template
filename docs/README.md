# Documentation

Welcome to the Full Stack FastAPI project documentation!

## Quick Navigation

### Getting Started
- **[Getting Started Guide](./getting-started.md)** - Complete setup instructions for new users
- **[Architecture Overview](../ARCHITECTURE.md)** - System design and component details

### Development
- **[Development Guide](../development.md)** - Local development workflows
- **[Backend README](../backend/README.md)** - Backend-specific documentation
- **[Frontend README](../frontend/README.md)** - Frontend-specific documentation

### Deployment
- **[Deployment Guide](../deployment.md)** - Production deployment instructions
- **[Deployment Checklist](./deployment-checklist.md)** - Step-by-step deployment verification

### Maintenance
- **[Troubleshooting Guide](./troubleshooting.md)** - Common issues and solutions
- **[Contributing Guide](./contributing.md)** - How to contribute to the project

## Documentation Structure

```
docs/
├── README.md                    # This file
├── getting-started.md           # New user onboarding
├── deployment-checklist.md      # Production deployment steps
├── troubleshooting.md           # Problem solving guide
└── contributing.md              # Contribution guidelines

Root level:
├── ARCHITECTURE.md              # System architecture overview
├── development.md               # Development workflows
├── deployment.md                # Deployment guide
├── README.md                    # Project overview
└── SECURITY.md                  # Security policy
```

## For Different Audiences

### I'm a New Developer
Start here:
1. [Getting Started](./getting-started.md) - Set up your environment
2. [Architecture](../ARCHITECTURE.md) - Understand the system
3. [Development Guide](../development.md) - Learn the workflow
4. [Contributing](./contributing.md) - Make your first contribution

### I'm Deploying to Production
Follow this path:
1. [Deployment Guide](../deployment.md) - Overview and concepts
2. [Deployment Checklist](./deployment-checklist.md) - Detailed steps
3. [Troubleshooting](./troubleshooting.md) - Bookmark for later

### I'm Maintaining the System
Useful resources:
1. [Troubleshooting Guide](./troubleshooting.md) - First stop for issues
2. [Architecture](../ARCHITECTURE.md) - System reference
3. [Development Guide](../development.md) - Docker commands and workflows

## Quick Reference

### Essential Commands

```bash
# Start development environment
docker compose watch

# Run tests
docker compose exec backend bash /app/scripts/test.sh
docker compose run --rm playwright npx playwright test

# View logs
docker compose logs -f [service-name]

# Access services
# Frontend:  http://localhost:5173
# Backend:   http://localhost:8000
# API Docs:  http://localhost:8000/docs
# Database:  http://localhost:8080 (Adminer)
```

### Common Tasks

| Task | Command |
|------|---------|
| Generate API client | `./scripts/generate-client.sh` |
| Create migration | `docker compose exec backend alembic revision --autogenerate -m "description"` |
| Apply migrations | `docker compose exec backend alembic upgrade head` |
| Access DB | `docker compose exec db psql -U postgres -d app` |
| Run linter | `cd backend && uv run prek run --all-files` |

## External Resources

### Framework Documentation
- [FastAPI](https://fastapi.tiangolo.com) - Backend framework
- [React](https://react.dev) - Frontend library
- [TanStack Query](https://tanstack.com/query) - Server state
- [TanStack Router](https://tanstack.com/router) - Routing
- [Tailwind CSS](https://tailwindcss.com) - Styling
- [shadcn/ui](https://ui.shadcn.com) - UI components

### Infrastructure
- [Docker](https://docs.docker.com) - Containerization
- [Traefik](https://doc.traefik.io/traefik/) - Reverse proxy
- [PostgreSQL](https://www.postgresql.org/docs/) - Database
- [Alembic](https://alembic.sqlalchemy.org) - Migrations

### Testing
- [Pytest](https://docs.pytest.org) - Backend testing
- [Playwright](https://playwright.dev) - E2E testing

## Need Help?

1. **Check Documentation**: Search these docs first
2. **Troubleshooting**: [Common issues and solutions](./troubleshooting.md)
3. **GitHub Issues**: Report bugs or request features
4. **Discussions**: Ask questions in GitHub Discussions

## Contributing to Docs

Found an error or want to improve documentation?

1. Edit the relevant `.md` file
2. Submit a PR with your changes
3. Follow the [Contributing Guide](./contributing.md)

Documentation improvements are always welcome!

---

**Last Updated**: January 2026
**Version**: 1.0.0
