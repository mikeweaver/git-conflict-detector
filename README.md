# Git Conflict Detector
The Git Conflict Detector is a tool that will automatically notify team members if their branches will conflict when merged. This allows team members to coordinate their efforts and avoid surprises further along with development.

## Setup
TBD

## Running with Cron
* To run the conflict detector rake task using cron, enter the following into crontab:
```
  0 5    *   *   *   /bin/bash -l -c 'source /home/ubuntu/.profile && cd /home/ubuntu/deploy/git-conflict-detector/current && bundle exec rake run:conflict_detector >> /home/ubuntu/deploy/git-conflict-detector/current/log/cron.log 2>&1'
```
* This will run your profile script, change directories to the app, then run the rake command.
* Output will be logged to log/cron.log

## Settings File
TBD
