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

- Superset: `8088` (mapped to host)
- PostgreSQL and Redis are **not** exposed to the host by default.

## Configuration

### Environment variables (`.env`)

| Variable | Default | Description |
|---|---|---|
| `SUPERSET_SECRET_KEY` | `super-secret-key-change-me` | Flask secret key — **change in production** |
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
| `make clean` | Destroy containers + volumes + local image + bind mount contents |

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

### Common issues

| Symptom | Likely fix |
|---|---|
| `make shell` fails — container not running | `make up` first |
| Superset not loading at <http://localhost:8088> | `make ps` to check health; `make logs-superset` to see startup errors |
| `make test` returns non-200 | Superset is still initializing — wait and retry |
| Port 8088 already in use | Change the host port in `docker-compose.yml` (`8088:8088` → `9090:8088`) |
| Database error after config change | `make clean` wipes volumes; or manually delete `volumes/postgres/` |
| **Port 5432 already in use** (PostgreSQL) | See dedicated section below |

### PostgreSQL volume issues (IMPORTANT)

The PostgreSQL data directory (`./volumes/postgres`) is a **bind mount** that persists on your host machine. This causes two common problems:

1. **"initdb" error / "database files exist but no initdb has been run"**: 
   - Happens when the postgres volume contains partial/corrupted data from a previous failed setup
   - **Fix**: Run `make clean` to completely wipe all volumes, then start fresh with `make build && make up`

2. **PostgreSQL container unhealthy or won't start**:
   - Often caused by leftover data files in `./volumes/postgres/` from a previous installation
   - The container expects either an empty directory OR a properly initialized database cluster
   - **Fix**: Run `make clean` to remove all persistent data, then rebuild and restart

**When in doubt, always run `make clean` before starting a fresh setup** to ensure no stale data interferes with initialization.

### PostgreSQL port 5432 already in use

If you have another PostgreSQL instance running on your host machine (e.g., from a local installation or another Docker container), port **5432** may already be occupied, causing the `superset-postgres` container to fail with "address already in use" or similar errors.

**Check if port 5432 is in use:**

```bash
# Linux
sudo netstat -tlnp | grep 5432
# or
sudo ss -tlnp | grep 5432

# macOS
lsof -i :5432
```

**Solutions:**

1. **Stop the conflicting PostgreSQL service** (if it's not needed):
   ```bash
   # If running as a system service
   sudo systemctl stop postgresql
   sudo systemctl disable postgresql
   
   # Or if it's another Docker container
   docker ps | grep postgres
   docker stop <container_id>
   ```

2. **Change the PostgreSQL port in this setup** (recommended if you need both instances):
   
   Edit `docker-compose.yml` and modify the postgres service ports:
   ```yaml
   services:
     postgres:
       image: postgres:18-alpine
       ports:
         - "5433:5432"  # Change host port from 5432 to 5433
       # ... rest of config
   ```
   
   Then update the database connection string in `docker/pythonpath/superset_config.py`:
   ```python
   SQLALCHEMY_DATABASE_URI = "postgresql+psycopg2://superset:superset@postgres:<NEW_PORT>/superset"
   ```
   Replace `<NEW_PORT>` with the new port number you configured (e.g., if you changed mapping to `5433:5432`, use `5433`).
   
   After making these changes, rebuild and restart:
   ```bash
   make rebuild
   ```

**Tip:** If you're not sure which approach to take, try stopping other PostgreSQL instances first. If you need both running simultaneously, change the port mapping as shown above.
