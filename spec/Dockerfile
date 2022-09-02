FROM ruby:2.7-slim-bullseye

COPY . /gem
WORKDIR /gem

RUN apt-get update && apt-get install -y git libsqlite3-dev sqlite3 make gcc && bundle install
CMD bundle exec rspec
