# System Diagrams

Additional technical diagrams for the Full Stack FastAPI project.

## Table of Contents
- [CI/CD Pipeline](#cicd-pipeline)
- [Database Schema](#database-schema)
- [Authentication Flow](#authentication-flow)
- [Request Lifecycle](#request-lifecycle)
- [Deployment Architecture](#deployment-architecture)

---

## CI/CD Pipeline

### GitHub Actions Workflow

```mermaid
graph TB
    Start[Developer Push/PR] --> Lint[Code Linting]
    Lint --> UnitTest[Unit Tests]
    UnitTest --> E2E[E2E Tests]
    E2E --> Build[Build Docker Images]

    Build --> Decision{Branch?}

    Decision -->|main| Staging[Deploy to Staging]
    Decision -->|release tag| Prod[Deploy to Production]
    Decision -->|other| End[End]

    Staging --> StagingTest[Smoke Tests]
    StagingTest --> StagingNotify[Notify Team]

    Prod --> ProdBackup[Backup Database]
    ProdBackup --> ProdDeploy[Deploy Application]
    ProdDeploy --> ProdSmoke[Smoke Tests]
    ProdSmoke --> ProdNotify[Notify Team]

    StagingNotify --> End
    ProdNotify --> End

    style Start fill:#4caf50
    style End fill:#2196f3
    style Prod fill:#ff9800
    style ProdBackup fill:#f44336
```

### Deployment Steps Detail

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant Runner as GitHub Runner
    participant Server as Production Server
    participant DB as Database

    Dev->>GH: Push code / Create tag
    GH->>Runner: Trigger workflow
    Runner->>Runner: Run tests
    Runner->>Runner: Build images
    Runner->>Server: SSH to server
    Server->>DB: Create backup
    Server->>Server: Pull new images
    Server->>Server: docker compose down
    Server->>Server: docker compose up
    Server->>DB: Run migrations
    Server->>Runner: Health check
    Runner->>GH: Update status
    GH->>Dev: Notify success/failure
```

---

## Database Schema

### Entity Relationship Diagram

```mermaid
erDiagram
    User ||--o{ Item : owns
    User {
        int id PK
        string email UK "unique, indexed"
        string hashed_password
        string full_name
        boolean is_active
        boolean is_superuser
        datetime created_at
        datetime updated_at
    }

    Item {
        int id PK
        string title
        string description
        int owner_id FK
        datetime created_at
        datetime updated_at
    }
```

### Schema with Indexes

```mermaid
graph TB
    subgraph Users["users table"]
        U1[id: SERIAL PRIMARY KEY]
        U2[email: VARCHAR UNIQUE]
        U3[hashed_password: VARCHAR]
        U4[full_name: VARCHAR]
        U5[is_active: BOOLEAN]
        U6[is_superuser: BOOLEAN]
        U7[created_at: TIMESTAMP]
    end

    subgraph Items["items table"]
        I1[id: SERIAL PRIMARY KEY]
        I2[title: VARCHAR]
        I3[description: TEXT]
        I4[owner_id: INTEGER FK]
        I5[created_at: TIMESTAMP]
    end

    subgraph Indexes["Database Indexes"]
        IDX1[idx_users_email]
        IDX2[idx_items_owner_id]
    end

    U2 -.->|indexed| IDX1
    I4 -.->|indexed + FK| IDX2
    I4 -->|foreign key| U1

    style Users fill:#4caf50
    style Items fill:#2196f3
    style Indexes fill:#ff9800
```

---

## Authentication Flow

### Complete Authentication Sequence

```mermaid
sequenceDiagram
    participant B as Browser
    participant F as Frontend
    participant BE as Backend API
    participant DB as PostgreSQL

    Note over B,DB: Login Flow
    B->>F: Enter credentials
    F->>BE: POST /api/v1/login/access-token
    BE->>DB: SELECT * FROM users WHERE email=?
    DB->>BE: Return user record
    BE->>BE: Verify password (bcrypt)

    alt Password Valid
        BE->>BE: Generate JWT token
        BE->>F: {access_token, token_type}
        F->>F: Store in memory
        F->>B: Redirect to /dashboard
    else Invalid Password
        BE->>F: 401 Unauthorized
        F->>B: Show error message
    end

    Note over B,DB: Authenticated Request Flow
    B->>F: User action
    F->>BE: API request + Authorization: Bearer {token}
    BE->>BE: Decode & validate JWT

    alt Token Valid
        BE->>DB: Query with user context
        DB->>BE: Return data
        BE->>F: JSON response
        F->>B: Update UI
    else Token Invalid/Expired
        BE->>F: 401 Unauthorized
        F->>F: Clear token
        F->>B: Redirect to /login
    end
```

### JWT Token Structure

```mermaid
graph LR
    subgraph JWT["JWT Token"]
        Header[Header<br/>alg: HS256<br/>typ: JWT]
        Payload[Payload<br/>sub: user_id<br/>exp: timestamp]
        Signature[Signature<br/>HMACSHA256]
    end

    Header --> Dot1[.]
    Dot1 --> Payload
    Payload --> Dot2[.]
    Dot2 --> Signature

    Secret[SECRET_KEY] -.->|signs| Signature

    style JWT fill:#e3f2fd
    style Secret fill:#f44336
```

### Password Reset Flow

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant B as Backend
    participant DB as Database
    participant Email as Email Service

    U->>F: Click "Forgot Password"
    F->>B: POST /api/v1/password-recovery/{email}
    B->>DB: Find user by email

    alt User Exists
        DB->>B: Return user
        B->>B: Generate reset token (JWT)
        B->>Email: Send reset email with token
        Email->>U: Email with reset link
        B->>F: 200 OK (generic message)
    else User Not Found
        B->>F: 200 OK (same message - security)
    end

    U->>F: Click reset link
    F->>F: Show password form
    U->>F: Enter new password
    F->>B: POST /api/v1/reset-password/<br/>{token, new_password}
    B->>B: Validate token
    B->>B: Hash new password
    B->>DB: UPDATE user SET password
    DB->>B: Success
    B->>F: 200 OK
    F->>U: Redirect to login
```

---

## Request Lifecycle

### HTTP Request Journey

```mermaid
graph TB
    Start[HTTP Request] --> Traefik[Traefik Proxy]
    Traefik -->|Route by path| Decision{Path?}

    Decision -->|/api/*| Backend[Backend Container]
    Decision -->|/*| Frontend[Frontend Container]

    Backend --> Auth[Authentication<br/>Middleware]
    Auth -->|Valid Token| Deps[Dependency<br/>Injection]
    Auth -->|Invalid Token| Err401[401 Unauthorized]

    Deps --> Handler[Route Handler<br/>Function]
    Handler --> Validate[Pydantic<br/>Validation]
    Validate --> DB[Database<br/>Query]

    DB --> Transform[SQLModel to<br/>Pydantic]
    Transform --> Response[JSON Response]

    Frontend --> Static[Serve Static<br/>React App]
    Static --> Browser[Browser Renders]

    Response --> Traefik2[Traefik Proxy]
    Err401 --> Traefik2
    Browser --> User[User Sees UI]
    Traefik2 --> User

    style Start fill:#4caf50
    style User fill:#2196f3
    style Err401 fill:#f44336
```

### Backend Request Processing

```mermaid
sequenceDiagram
    participant C as Client
    participant M as Middleware
    participant R as Router
    participant V as Validator
    participant H as Handler
    participant D as Database

    C->>M: HTTP Request
    M->>M: CORS Check
    M->>M: JWT Validation
    M->>R: Forward Request
    R->>R: Match Route
    R->>V: Parse Parameters
    V->>V: Pydantic Validation

    alt Validation Fails
        V->>C: 422 Validation Error
    else Validation Success
        V->>H: Call Handler
        H->>D: Execute Query
        D->>H: Return Data
        H->>H: Transform to Response Model
        H->>C: 200 JSON Response
    end
```

---

## Deployment Architecture

### Production Infrastructure

```mermaid
graph TB
    subgraph Internet["Internet"]
        User[Users]
    end

    subgraph CloudProvider["Cloud Provider (AWS/DO/GCP)"]
        subgraph LoadBalancer["Load Balancer (Optional)"]
            LB[Nginx/ALB]
        end

        subgraph Server["Application Server"]
            Traefik[Traefik Proxy]

            subgraph Docker["Docker Compose Stack"]
                Frontend[Frontend<br/>Nginx]
                Backend1[Backend<br/>Replica 1]
                Backend2[Backend<br/>Replica 2]
            end
        end

        subgraph Data["Data Layer"]
            DB[(PostgreSQL<br/>Primary)]
            DBReplica[(PostgreSQL<br/>Read Replica)]
            Redis[(Redis Cache<br/>Optional)]
        end

        subgraph Storage["Storage"]
            Volumes[Docker Volumes]
            S3[Object Storage<br/>S3/Spaces]
        end

        subgraph Monitoring["Monitoring"]
            Logs[Log Aggregation]
            Metrics[Metrics/Grafana]
            Alerts[Alert Manager]
        end
    end

    subgraph External["External Services"]
        DNS[DNS Provider]
        Email[SMTP Service<br/>Mailgun/SendGrid]
        Sentry[Error Tracking<br/>Sentry]
    end

    User -->|HTTPS| DNS
    DNS --> LB
    LB --> Traefik
    Traefik --> Frontend
    Traefik --> Backend1
    Traefik --> Backend2

    Backend1 --> DB
    Backend2 --> DB
    Backend1 --> DBReplica
    Backend2 --> DBReplica
    Backend1 -.->|optional| Redis
    Backend2 -.->|optional| Redis

    Backend1 --> Email
    Backend2 --> Email
    Backend1 --> Sentry
    Backend2 --> Sentry

    Frontend --> S3
    DB --> Volumes

    Traefik -.-> Logs
    Backend1 -.-> Logs
    Backend2 -.-> Logs
    Backend1 -.-> Metrics
    Backend2 -.-> Metrics

    Logs -.-> Alerts
    Metrics -.-> Alerts

    style User fill:#4caf50
    style DB fill:#9c27b0
    style Traefik fill:#ff9800
```

### Scaling Strategy

```mermaid
graph TB
    subgraph Growth["As Traffic Grows"]
        Stage1[Single Server<br/>All Services]
        Stage2[Vertical Scaling<br/>More CPU/RAM]
        Stage3[Separate DB<br/>Managed Service]
        Stage4[Multiple Backend<br/>Replicas]
        Stage5[Load Balancer<br/>Multiple Servers]
        Stage6[Add Caching<br/>Redis/CDN]
    end

    Stage1 --> Stage2
    Stage2 --> Stage3
    Stage3 --> Stage4
    Stage4 --> Stage5
    Stage5 --> Stage6

    style Stage1 fill:#4caf50
    style Stage6 fill:#f44336
```

---

## Development Workflow

### Feature Development Lifecycle

```mermaid
graph TB
    Start[Create Feature Branch] --> Code[Write Code]
    Code --> Test[Write Tests]
    Test --> Local[Test Locally]
    Local -->|Failed| Code
    Local -->|Passed| Commit[Git Commit]

    Commit --> Push[Push to GitHub]
    Push --> PR[Create Pull Request]

    PR --> CI[CI Pipeline Runs]
    CI --> CITest{Tests Pass?}

    CITest -->|No| Fix[Fix Issues]
    Fix --> Code

    CITest -->|Yes| Review[Code Review]
    Review --> Changes{Changes Needed?}

    Changes -->|Yes| Code
    Changes -->|No| Approve[Approve PR]

    Approve --> Merge[Merge to Main]
    Merge --> StagingDeploy[Auto Deploy Staging]
    StagingDeploy --> Verify[Verify Staging]

    Verify --> Tag{Ready for Prod?}
    Tag -->|No| Wait[Wait]
    Tag -->|Yes| Release[Create Release Tag]
    Release --> ProdDeploy[Deploy Production]
    ProdDeploy --> Monitor[Monitor & Celebrate]

    style Start fill:#4caf50
    style Monitor fill:#2196f3
    style Fix fill:#f44336
```

---

## Docker Compose Architecture

### Service Dependencies

```mermaid
graph TB
    subgraph External["External Networks"]
        Internet[Internet Traffic]
    end

    subgraph TraefikNet["traefik-public network"]
        Traefik[Traefik Proxy]
    end

    subgraph DefaultNet["default network"]
        Frontend[Frontend]
        Backend[Backend]
        Prestart[Prestart<br/>Migrations]
        DB[(PostgreSQL)]
        Adminer[Adminer]
        Mail[Mailcatcher]
    end

    Internet --> Traefik
    Traefik -.-> Frontend
    Traefik -.-> Backend

    Prestart -->|runs before| Backend
    Backend --> DB
    Frontend --> Backend
    Adminer --> DB
    Backend --> Mail

    DB -->|depends on| Healthy{DB Healthy?}
    Healthy -->|yes| Prestart

    style Traefik fill:#ff9800
    style DB fill:#9c27b0
    style Prestart fill:#ffc107
```

---

## Use These Diagrams

### In Presentations
Copy any Mermaid code block directly into:
- Markdown slides (Marp, reveal.js)
- Mermaid Live Editor: https://mermaid.live
- Documentation tools (GitBook, Docusaurus)

### For Documentation
- Link to this file from your docs
- Embed in README or wiki
- Include in technical proposals

### For Learning
- Walk through authentication flow with students
- Explain deployment architecture
- Show CI/CD pipeline process

---

**Tip**: These diagrams are maintained as code, making them easy to update and version control! 🎨
