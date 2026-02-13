ExpenseFlow is a lightweight expense approval system built using **n8n +
PostgreSQL + Docker**.

It demonstrates:

-   Token-based authentication
-   Role-Based Access Control (ADMIN / SUPERVISOR / EMPLOYEE)
-   Structured relational schema with constraints & indexes
-   Deterministic Docker startup with automatic DB bootstrapping
-   Clean separation between workflow logic and persistence

The entire environment runs locally using Docker.

------------------------------------------------------------------------

## Architecture

```text
EXPENSEFLOW
│
├── db/
│   └── bootstrap/
│       └── 001_expenseflow_bootstrap.sql
│
├── flows/
│   ├── Admin — Rotate Token (POST).json
│   ├── Employee dashboard (GET).json
│   ├── ExpenseFlow - Admin - Create Employee (GET).json
│   ├── ExpenseFlow - Admin - Create Employee (POST).json
│   ├── ExpenseFlow - Get Claim Form (GET).json
│   ├── ExpenseFlow - Submit Claim (POST).json
│   ├── ExpenseFlow - Supervisor Decision (POST).json
│   ├── ExpenseFlow — Admin — Delete User (POST).json
│   ├── ExpenseFlow — Admin — Toggle Active (POST).json
│   ├── ExpenseFlow — Admin — Update Role (POST).json
│   ├── ExpenseFlow — Admin Dashboard (GET).json
│   ├── ExpenseFlow — Auth — Login (GET).json
│   ├── ExpenseFlow — Auth — Login (POST).json
│   ├── ExpenseFlow — Auth — Logout (GET).json
│   └── Supervisor dashboard (GET).json
│
├── .gitignore
├── docker-compose.yml
└── README.md

```



When running `docker compose up`:

1.  PostgreSQL starts.
2.  A preflight container ensures the schema is ready.
3.  A default admin user is created if missing.
4.  n8n starts only after the database is prepared.

------------------------------------------------------------------------

## Quick Start

Clone the repository:

``` bash
git clone https://github.com/barel26497/ExpenseFlow
cd ExpenseFlow
```

Start the system:

``` bash
docker compose up -d
```

Open n8n:

http://localhost:5678

------------------------------------------------------------------------

## Default Admin

The system automatically creates a default admin user (if missing):

```text
Email: admin@local
Password: Admin123!
Role: ADMIN
```

------------------------------------------------------------------------

## Important: Import the n8n Flows Manually

The repository does NOT automatically import workflows.

After first startup:

1.  Open n8n in the browser.
2.  Go to Workflows → Create a new flow → Import from File.
3.  Upload the JSON workflow files included in this repository (15 in total)
4.  Publish each of the workflows.

Without importing the flows, the application will not function.

------------------------------------------------------------------------

## Connecting n8n to PostgreSQL

Inside the n8n UI:

1.  Go to Credentials.
2.  Click New Credential.
3.  Select PostgreSQL.

Use the following configuration:

```text
Host: postgres
Database: expenseflow
User: expenseflow
Password: expenseflow
Port: 5432
```


Explanation:

-   `postgres` is the Docker service name.
-   SSL is unnecessary because communication is internal to Docker.
-   SSH tunneling is not required for local containers.

------------------------------------------------------------------------

## Resetting the Database

To wipe everything and start fresh:

``` bash
docker compose down -v
docker compose up -d
```

The `-v` flag removes the PostgreSQL volume.

------------------------------------------------------------------------

## Database Bootstrapping

The project includes an idempotent SQL bootstrap script:

db/bootstrap/001_expenseflow_bootstrap.sql

This script automatically:

-   Ensures pgcrypto extension exists
-   Creates required tables
-   Adds constraints and indexes
-   Ensures foreign keys exist
-   Creates the default admin user if missing

The script runs via a dedicated `db-preflight` container before n8n
starts.

------------------------------------------------------------------------

## Security Notes

-   Passwords are stored using bcrypt via PostgreSQL `crypt()`
    (pgcrypto).
-   Tokens are randomly generated (32 bytes, hex encoded).
-   Token expiration logic is handled at the n8n workflow level.
-   No plaintext passwords are stored in the database.

------------------------------------------------------------------------

## Project Purpose

This repository demonstrates:

-   Structured schema design
-   Docker orchestration best practices
-   Deterministic environment bootstrapping
-   Practical RBAC implementation using low-code tooling

It is intentionally simple while architecturally clean and reproducible.
