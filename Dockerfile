FROM ruby:2.1.10

ARG RAILS_ENV

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
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/src/pre_deploy_checker

WORKDIR /usr/src/pre_deploy_checker

RUN cd .. && \
    git clone git://git.kernel.org/pub/scm/git/git.git && \
    cd git && \
    make configure && \
    ./configure --prefix=/usr && \
    make install && \
    cd ../pre_deploy_checker

RUN mkdir -p shared/pids && \
    mkdir -p log

COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install

COPY . .

RUN bundle exec rake db:migrate RAILS_ENV=$RAILS_ENV VALIDATE_SETTINGS=false
