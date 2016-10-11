#!/bin/sh
mkdir ~/.ssh
echo -n $GITHUB_PRIVATE_KEY > ~/.ssh/id_rsa
echo -n $GITHUB_PUBLIC_KEY > ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub
ssh-keyscan github.com > ~/.ssh/known_hosts
eval "$(ssh-agent -s)"
echo -n $JIRA_PRIVATE_KEY > ./jira_rsakey.pem
bundle exec rake jobs:work
