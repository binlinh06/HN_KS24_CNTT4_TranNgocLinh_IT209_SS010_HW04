
#!/usr/bin/env bash
set -eu

NETWORK="app-net"
VOLUME="db-data"
DB_CONTAINER="db-server"
APP_CONTAINER="app-container"
DB_IMAGE="postgres:15-alpine"
APP_IMAGE="hw-backend:v1"

# 1. Create custom bridge network
docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create --driver bridge "$NETWORK"

# 2. Create named volume
docker volume inspect "$VOLUME" >/dev/null 2>&1 || \
  docker volume create "$VOLUME"

# 3. Remove old lab containers if they exist
docker rm -f "$APP_CONTAINER" "$DB_CONTAINER" 2>/dev/null || true

# 4. Start PostgreSQL with persistent storage
docker run -d \
  --name "$DB_CONTAINER" \
  --network "$NETWORK" \
  --network-alias "$DB_CONTAINER" \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=LabPassword123 \
  -e POSTGRES_DB=appdb \
  -v "$VOLUME:/var/lib/postgresql/data" \
  "$DB_IMAGE"

# 5. Wait until PostgreSQL is ready
echo "Waiting for PostgreSQL..."
ready=0
for i in $(seq 1 30); do
  if docker exec "$DB_CONTAINER" \
    pg_isready -U appuser -d appdb >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done

if [ "$ready" -ne 1 ]; then
  echo "ERROR: PostgreSQL did not become ready."
  docker logs "$DB_CONTAINER"
  exit 1
fi

# 6. Start backend on the same network
docker run -d \
  --name "$APP_CONTAINER" \
  --network "$NETWORK" \
  -p 8080:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASSWORD=LabPassword123 \
  "$APP_IMAGE"

echo "Lab environment started successfully."
echo "Network: $NETWORK"
echo "Volume: $VOLUME"
echo "Database container: $DB_CONTAINER"
echo "Backend container: $APP_CONTAINER"
