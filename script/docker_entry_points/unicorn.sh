#!/bin/sh
SCRIPT_DIR=`dirname "$0"`
sh $SCRIPT_DIR/common.sh
bundle exec unicorn -c config/unicorn_docker.rb
