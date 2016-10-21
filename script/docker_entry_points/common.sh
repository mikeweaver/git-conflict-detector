#!/bin/sh
mkdir -p ~/.ssh
if [ -n "$SETTINGS_FILE_CONTENT" ]; then
    echo -n $SETTINGS_FILE_CONTENT > ./data/config/settings.$RAILS_ENV.yml
fi
if [ -n "$GITHUB_PRIVATE_KEY" ]; then
    mkdir -p ~/.ssh
    echo -n $GITHUB_PRIVATE_KEY > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    ssh-keyscan github.com > ~/.ssh/known_hosts 2>/dev/null
    eval "$(ssh-agent -s)"
fi
if [ -n "$JIRA_PRIVATE_KEY" ]; then
    echo -n $JIRA_PRIVATE_KEY > ./jira_rsakey.pem
fi
