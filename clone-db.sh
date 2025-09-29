#!/bin/bash
set -o allexport


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"
source "${SCRIPT_DIR}/.db"

set +o allexport




echo "--------------------------------------------------------------------"
echo
echo "Connecting to database at $DEVELOP_HOST:$DEVELOP_PORT with user $DEVELOP_USER"
echo 
echo "--------------------------------------------------------------------"

echo
echo "Fetching list of databases from the develop environment..."

# Fetch list of databases using psql inside a temporary Docker container
DB_LIST=$(docker run --rm \
  -e PGPASSWORD=$DEVELOP_PASSWORD \
  --network host \
  postgis/postgis \
  psql -h $DEVELOP_HOST -p $DEVELOP_PORT -U $DEVELOP_USER -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")
if [ $? -ne 0 ]; then
  echo "Error: Unable to fetch database list from develop environment."
  exit 1
fi

echo
echo "Available databases:"
echo "$DB_LIST" | nl
echo

read -p "Enter the number corresponding to the database you want to backup: " DB_NUMBER
SELECTED_DB=$(echo "$DB_LIST" | sed -n "${DB_NUMBER}p" | xargs)
if [ -z "$SELECTED_DB" ]; then
  echo "Error: Invalid selection."
  exit 1
fi

echo
echo "You selected database: $SELECTED_DB"

echo "--------------------------------------------------------------------"
# Xóa database cũ trong container Docker
echo
echo "--------------------------------------------------------------------"
echo
echo "Fetching list of running Docker containers..."
CONTAINER_LIST=$(docker ps --format '{{.Names}}')
echo "$CONTAINER_LIST" | nl
echo

read -p "Enter the number corresponding to the Docker container you want to use: " CONTAINER_NUMBER
SELECTED_CONTAINER=$(echo "$CONTAINER_LIST" | sed -n "${CONTAINER_NUMBER}p" | xargs)

if [ -z "$SELECTED_CONTAINER" ]; then
  echo "Error: Invalid container selection."
  exit 1
fi

echo
echo "You selected container: $SELECTED_CONTAINER"
echo "--------------------------------------------------------------------"
echo "--------------------------------------------------------------------"
# Đặt tên file backup theo định dạng <tên_db>_DDMMYY.sql
DATE_TAG=$(date +%d%m%y)
BACKUP_FILE="${SELECTED_DB}_${DATE_TAG}.sql"


# Dump database from develop using pg_dump inside a temporary Docker container
echo
echo "--------------------------------------------------------------------"
echo
echo "Dumping database $SELECTED_DB from develop environment..."
echo
docker run --rm \
  -e PGPASSWORD=$DEVELOP_PASSWORD \
  -v "$PWD":/backup \
  --network host \
  postgis/postgis \
  pg_dump --verbose -h $DEVELOP_HOST -p $DEVELOP_PORT -U $DEVELOP_USER -d $SELECTED_DB -F c -f /backup/$BACKUP_FILE
if [ $? -ne 0 ]; then
  echo "Error: Failed to dump database $SELECTED_DB from develop environment."
  exit 1
fi

echo
echo
echo "Database dumped successfully to $BACKUP_FILE."

echo "--------------------------------------------------------------------"


# Drop and create database using psql inside the selected Docker container
docker exec -e PGPASSWORD=$LOCAL_PASSWORD $SELECTED_CONTAINER psql -U $LOCAL_USER -d postgres -c "DROP DATABASE IF EXISTS $SELECTED_DB;"
if [ $? -ne 0 ]; then
  echo "Error: Failed to drop the old database $SELECTED_DB in Docker container."
  exit 1
fi

echo "Creating new database $SELECTED_DB in Docker container..."
docker exec -e PGPASSWORD=$LOCAL_PASSWORD $SELECTED_CONTAINER psql -U $LOCAL_USER -d postgres -c "CREATE DATABASE $SELECTED_DB;"
if [ $? -ne 0 ]; then
  echo "Error: Failed to create the new database $SELECTED_DB in Docker container."
  exit 1
fi

# Copy file backup vào container Docker
echo "Copying backup file into Docker container..."
docker cp $BACKUP_FILE $SELECTED_CONTAINER:/tmp/$BACKUP_FILE
if [ $? -ne 0 ]; then
  echo "Error: Failed to copy backup file into Docker container."
  exit 1
fi


# Restore database using pg_restore inside the selected Docker container
echo "Restoring database $SELECTED_DB in Docker container..."
docker exec -e PGPASSWORD=$LOCAL_PASSWORD $SELECTED_CONTAINER pg_restore -U $LOCAL_USER -d $SELECTED_DB -F c /tmp/$BACKUP_FILE
if [ $? -ne 0 ]; then
  echo "Error: Failed to restore database $SELECTED_DB in Docker container."
  exit 1
fi

# Xóa file backup trong container và máy local
echo "Cleaning up backup files..."
rm -f $BACKUP_FILE
docker exec $SELECTED_CONTAINER rm -f /tmp/$BACKUP_FILE

echo
echo "Database $SELECTED_DB sync from develop to local (Docker) completed successfully!"
