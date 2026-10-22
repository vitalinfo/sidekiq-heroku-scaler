ARG RUBY_VERSION=4.0
FROM ruby:${RUBY_VERSION}-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git libyaml-dev \
  && rm -rf /var/lib/apt/lists/*

# The gemspec lists its files with `git ls-files`, and the mounted repo is owned by the host user.
RUN git config --global --add safe.directory /gem

WORKDIR /gem

COPY Gemfile Gemfile.lock sidekiq-heroku-scaler.gemspec ./
COPY lib/sidekiq-heroku-scaler/version.rb lib/sidekiq-heroku-scaler/
RUN bundle install

COPY . .
