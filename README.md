# Superset Env Setup

A self-contained Apache Superset development environment using Docker Compose.
One command to get a running Superset with a PostgreSQL database and Redis cache.

## Quick start

```bash
make setup-env    # create .env from .env.example (safe to re-run)
make build        # build the custom Superset image
make up           # start PostgreSQL, Redis, and Superset
make init         # run db upgrade + initialize Superset
make create-admin # create an admin user
```

Open <http://localhost:8088> and log in with the credentials you set during `make create-admin`.

## Prerequisites

- **Docker** 24+ with Compose V2 (the `docker compose` plugin, not the standalone `docker-compose` binary)
- **curl** — only needed for `make test`
- Port **8088** free on the host

## Project structure

```
├── docker/
│   ├── pythonpath/
│   │   └── superset_config.py    # Superset config (DB, Redis, cache)
│   └── requirements.txt          # Extra Python packages installed into the image
├── volumes/
│   ├── postgres/                 # PostgreSQL data directory (persistent)
│   └── superset_home/            # Superset home (SQLite, uploaded images, etc.)
├── .env                          # Environment variables (git-ignored)
├── .env.example                  # Template — copy to .env and edit
├── .gitignore
├── docker-compose.yml            # Service definitions
├── Dockerfile                    # Image customization on top of apache/superset:6.0.0
├── Makefile                      # Command shortcuts
└── README.md                     # This file
```

## Services

| Service | Image | Role |
|---|---|---|
| **postgres** | `postgres:18-alpine` | Metadata database — dashboards, charts, users |
| **redis** | `redis:7-alpine` | Cache backend — query results, UI filters, explore forms |
| **superset** | `superset-custom:6.0.0` | Apache Superset application server (Gunicorn) |

All three have health checks. Superset waits for PostgreSQL and Redis to be healthy before starting.

### Ports

| Service | Host (default) | Container | Configurable via |
|---|---|---|---|
| **superset** | `8088` | `8088` | Edit `docker-compose.yml` |
| **postgres** | `5432` | `5432` | `POSTGRES_PORT` in `.env` |
| **redis** | *not exposed* | `6379` | — |

PostgreSQL is exposed to the host so you can connect with local tools
(psql, DBeaver, TablePlus). If port **5432 is already in use** on your
host, set a different port in `.env`:

```bash
POSTGRES_PORT=5433   # any free port
```

Then `make up` again.

## Configuration

### Environment variables (`.env`)

| Variable | Default | Description |
|---|---|---|
| `SUPERSET_SECRET_KEY` | `super-secret-key-change-me` | Flask secret key — **change in production** |
| `POSTGRES_HOST` | `postgres` | PostgreSQL hostname (Docker service name) |
| `POSTGRES_PORT` | `5432` | PostgreSQL port exposed on the host |
| `POSTGRES_DB` | `superset` | PostgreSQL database name |
| `POSTGRES_USER` | `superset` | PostgreSQL user |
| `POSTGRES_PASSWORD` | `superset` | PostgreSQL password — **change in production** |
| `REDIS_HOST` | `redis` | Redis hostname (Docker service name) |
| `REDIS_PORT` | `6379` | Redis port |
| `REDIS_DB` | `0` | Redis database index |

Copy `.env.example` to `.env` and edit values:

```bash
cp .env.example .env
# or: make setup-env
```

### Python dependencies (`docker/requirements.txt`)

Extra Python packages installed during `make build`. Default includes:

- **redis** — Redis cache backend driver
- **psycopg2-binary** — PostgreSQL driver
- **pymssql** — Microsoft SQL Server database engine (for connecting to external MSSQL datasources)

Add any other packages (database drivers, auth backends, etc.) here and rebuild with `make rebuild`.

### Superset configuration (`docker/pythonpath/superset_config.py`)

Configured out of the box:

- PostgreSQL as the metadata database
- Redis for all cache layers (results, filter state, explore form data)
- Cache TTL: 24 hours

Edit this file to add extra Superset features (e.g., Celery async queries, custom auth, feature flags), then `make rebuild`.

### Data persistence

| Volume mount | What it holds |
|---|---|
| `./volumes/postgres` | PostgreSQL data files |
| `./volumes/superset_home` | Superset home directory |
| `redis-data` (named volume) | Redis append-only log |

- PostgreSQL and Superset home are mounted as **bind mounts** — data lives in the project directory.
- Redis uses a **named Docker volume** for its AOF persistence.

To start fresh: `make clean` deletes volumes and the local image.

## Makefile reference

### Lifecycle

| Command | What it does |
|---|---|
| `make build` | Build the Superset image with `--no-cache` |
| `make up` | Create and start all containers in detached mode |
| `make down` | Stop and remove containers |
| `make start` | Start stopped containers |
| `make stop` | Stop running containers |
| `make restart` | Restart all containers |
| `make rebuild` | Build image, then recreate containers (`build` + `up --force-recreate`) |
| `make clean` | Destroy containers + volumes + local image |

### Monitoring

| Command | What it does |
|---|---|
| `make ps` / `make status` | List containers with their status |
| `make logs` | Tail logs from all services |
| `make logs-superset` | Tail logs from superset only |
| `make logs-postgres` | Tail logs from postgres only |
| `make logs-redis` | Tail logs from redis only |

### Superset commands

| Command | What it does |
|---|---|
| `make shell` | Open a bash shell inside the Superset container |
| `make exec cmd="..."` | Run an arbitrary command inside the Superset container |
| `make init` | Run `superset db upgrade` + `superset init` |
| `make create-admin` | Create an admin user interactively |
| `make test` | Check if Superset is responding on port 8088 |

### Setup & maintenance

| Command | What it does |
|---|---|
| `make setup-env` | Copy `.env.example` → `.env` if `.env` doesn't exist |
| `make pull` | Pull postgres and redis base images |
| `make prune` | Prune unused Docker objects |

## Adding a database engine

1. Add the Python driver to `docker/requirements.txt` (e.g., `mysqlclient` for MySQL)
2. Run `make rebuild` to install it and restart
3. Connect in Superset UI via the corresponding SQLAlchemy URI

Common drivers: `psycopg2-binary` (PostgreSQL, already installed), `mysqlclient` (MySQL), `pymssql` (MSSQL, already installed), `clickhouse-connect` (ClickHouse).

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `make shell` fails — container not running | `make up` first |
| Superset not loading at <http://localhost:8088> | `make ps` to check health; `make logs-superset` to see startup errors |
| `make test` returns non-200 | Superset is still initializing — wait and retry |
| Port 8088 already in use | Change the host port in `docker-compose.yml` (`8088:8088` → `9090:8088`) |
| Want everything from scratch | `make clean && make build && make up && make init && make create-admin` |
| Database error after config change | `make clean` wipes volumes; or manually delete `volumes/postgres/` |

### PostgreSQL volume issues

The PostgreSQL data directory (`./volumes/postgres`) is a **bind mount** that
persists on your host machine. This causes two common problems when starting
fresh after a failed or partial setup:

1. **"initdb" error / "database files exist but no initdb has been run"**
   - The volume contains partial/corrupted data from a previous setup
   - **Fix**: `make clean` wipes everything. Then `make build && make up`.

2. **PostgreSQL container unhealthy or won't start**
   - Leftover data files in `./volumes/postgres/` confuse the container
   - The container expects either an **empty** directory or a properly
     initialized database cluster — anything in between fails
   - **Fix**: `make clean` to remove all persistent data, then rebuild.

> When in doubt, always run `make clean` before starting a fresh setup to
> ensure no stale data interferes with initialization.

### PostgreSQL 18+ volume layout change

Postgres 18+ images changed the expected volume mount. Instead of mounting at
`/var/lib/postgresql/data`, they expect the mount at `/var/lib/postgresql`
(the parent dir) so data lands in a version-specific subdirectory (e.g.,
`/var/lib/postgresql/18/data`). This enables `pg_upgrade --link` across
major versions without mount boundary issues.

**Error**:

```
Error: in 18+, these Docker images are configured to store database data in a
       format which is compatible with "pg_ctlcluster"...
```

**Fix**: The volume mount in `docker-compose.yml` already uses the correct
path (`./volumes/postgres:/var/lib/postgresql`). If you modified it, ensure
the mount point is `/var/lib/postgresql`, **not** `/var/lib/postgresql/data`.
After correcting, run:

```bash
make down && make up
```

### ".gitkeep" blocking PostgreSQL init

If `volumes/postgres/` contains a `.gitkeep` file (or any other file), the
PostgreSQL container refuses to initialize because it expects an empty
directory:

```
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
```

**Fix**:

```bash
rm volumes/postgres/.gitkeep
make down && make up
```

If you already ran a failed attempt, also do `rm -rf volumes/postgres/*` to
ensure a clean slate.

### Port conflict on the host

If `docker compose up` fails with "port is already allocated", check which
service owns the busy port:

| Port | Service | Fix |
|---|---|---|
| `8088` | superset | Edit the host port in `docker-compose.yml` (`8088:8088` → `9090:8088`) |
| `5432` | postgres | Set `POSTGRES_PORT=5433` (or any free port) in `.env` |

After changing the port, run:

```bash
make down && make up
```
