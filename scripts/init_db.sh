#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed."
    echo >&2 "Use:"
    echo >&2 "  cargo install --version='~0.8' sqlx-cli --no-default-features --features rustls,postgres"
    echo >&2 "to install sqlx."
    exit 1
fi

# Check if a custom parameter has been ste, otherwise use default values
DB_PORT="${POSTGRES_PORT:=5432}"
SUPERUSER="${SUPERUSER:=postgres}"
SUPERUSER_PASSWORD="${SUPERUSER_PASSWORD:=postgres}"
APP_USER="${APP_USER:=app}"
APP_USER_PASSWORD="${APP_USER_PASSWORD:=secret}"
APP_DB_NAME="${APP_DB_NAME:=newsletter}"
DATABASE_URL="postgres://${APP_USER}:${APP_USER_PASSWORD}@localhost:${DB_PORT}/${APP_DB_NAME}"
export DATABASE_URL

#launch postgres using docker
CONTAINER_NAME=postgres
docker run --name $CONTAINER_NAME -e POSTGRES_PASSWORD="$SUPERUSER_PASSWORD" -e POSTGRES_USER="$SUPERUSER" --health-cmd="pg_isready -U $SUPERUSER || exit 1" --health-interval=1s --health-timeout=5s --health-retries=5 -p "$DB_PORT":5432 --detach "postgres:latest" -N 1000

until [ "$(docker inspect -f "{{ .State.Health.Status }}" $CONTAINER_NAME)" == "healthy" ]; do
    >&2 echo "Postgres is unavailable - sleeping"
    sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT}!"

# create the application user
CREATE_QUERY="CREATE USER $APP_USER WITH PASSWORD '$APP_USER_PASSWORD';"
docker exec -it $CONTAINER_NAME psql -U "$SUPERUSER" -c "$CREATE_QUERY"

# Grant create db privileges to application user
GRANT_QUERY="ALTER USER $APP_USER CREATEDB;"
docker exec -it $CONTAINER_NAME psql -U "$SUPERUSER" -c "$GRANT_QUERY"

sqlx database create
sqlx migrate run