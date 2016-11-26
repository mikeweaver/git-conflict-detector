FROM ruby:2.1.10

ARG RAILS_ENV
ENV HOME_DIR="/usr/src/pre_deploy_checker"

RUN apt-get update && \
    apt-get install -y \
    build-essential \
    git-core \
    sqlite3 \
    libsqlite3-dev \
    nodejs \
    libcurl4-gnutls-dev \
    libexpat1-dev \
    gettext \
    libz-dev \
    libssl-dev && \
    # remove apt-get data to save space
    rm -rf /var/lib/apt/lists/* && \
    # build the git client (we need a newer version that ships with debian)
    git clone git://git.kernel.org/pub/scm/git/git.git && \
    cd git && \
    git checkout e2b2d6a172b76d44cb7b1ddb12ea5bfac9613a44 && \
    make configure && \
    ./configure --prefix=/usr && \
    make install && \
    # make a directory for our app
    mkdir -p ${HOME_DIR}

WORKDIR ${HOME_DIR}

COPY Gemfile .
COPY Gemfile.lock .

RUN \
# make SSH be quiet about githubs SSH key
mkdir -p /root/.ssh && \
ssh-keyscan github.com >> /root/.ssh/known_hosts && \
# install minimal set of required gems
bundle install --without test development

COPY . .

RUN \
# make some directories we need to run
mkdir -p shared/pids && \
mkdir -p log && \
mkdir -p data/db && \
# setup the DB and assets
bundle exec rake db:migrate RAILS_ENV=$RAILS_ENV VALIDATE_SETTINGS=false && \
bundle exec rake assets:precompile RAILS_ENV=$RAILS_ENV VALIDATE_SETTINGS=false
