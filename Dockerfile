FROM ruby:3.4.4 AS build
WORKDIR /tmp
RUN apt update && apt install -y ragel
COPY Gemfile Gemfile.lock fumimi-discord.gemspec ./
RUN gem install bundler:2.6.9
RUN bundle config set without "development test"
RUN bundle install

FROM ruby:3.4.4-slim
WORKDIR /root
RUN apt update && apt install -y libsodium-dev libglib2.0-dev libpq-dev
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

ENV LANG=C.UTF-8
ENTRYPOINT ["bundle", "exec", "ruby", "bin/fumimi"]
