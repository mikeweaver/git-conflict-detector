#!/bin/sh
mkdir -p ~/.ssh
echo -n $GITHUB_PRIVATE_KEY > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-keyscan github.com > ~/.ssh/known_hosts
eval "$(ssh-agent -s)"
echo -n $JIRA_PRIVATE_KEY > ./jira_rsakey.pem
bundle exec rake jobs:work
