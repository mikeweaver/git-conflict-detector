#!/bin/bash

set -e

show_usage () {
    echo "USAGE: deploy [-s] -p DEPLOY TO PATH" >&2
    exit 1
}
SILENT=0
DEPLOY_PATH=

while getopts ":sp:" opt; do
  case $opt in
    s)
      SILENT=1
      ;;
    p)
      DEPLOY_PATH=$OPTARG
      ;;
    \?)
      show_usage
      ;;
  esac
done

if [ "$DEPLOY_PATH" = "" ]; then
  show_usage
fi

if [ "$SILENT" -ne "1" ]; then
  echo "Deploying from this folder to $DEPLOY_PATH"
  read -p "Press any key to continue, Ctrl-C to abort"
fi

NOW=$(date +"%Y-%m-%d_%H.%M.%S")
BACKUP_PATH="$DEPLOY_PATH.$NOW"
SCRIPT_DIRECTORY=`dirname $0`
STAGING_PATH=$(cd "$SCRIPT_DIRECTORY/.." ; pwd)

echo "Stopping services"
sudo service delayed-job stop
sudo service nginx stop
sudo service unicorn stop

echo "Backing up current deploy"
mv "$DEPLOY_PATH" "$BACKUP_PATH"

echo "Promoting staging to current"
mv "$STAGING_PATH" "$DEPLOY_PATH"
cd "$DEPLOY_PATH"

echo "Restoring current DB and settings"
cp "$BACKUP_PATH/db/production.sqlite3" "$DEPLOY_PATH/db/"
cp "$BACKUP_PATH/config/settings.production.yml" "$DEPLOY_PATH/config/"
cp "$BACKUP_PATH/config/database.yml" "$DEPLOY_PATH/config/"

echo "Bundling"
bundle install

echo "Migrating DB"
bundle exec rake db:migrate

echo "Starting services"
mkdir -p $DEPLOY_PATH/shared/pids $DEPLOY_PATH/shared/sockets
sudo service nginx start
sudo service unicorn start
sudo service delayed-job start

echo "Complete"
