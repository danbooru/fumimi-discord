FROM ruby:2.6.5 AS build
WORKDIR /tmp
COPY Gemfile Gemfile.lock fumimi-discord.gemspec .
RUN bundle install --with=production

FROM ruby:2.6.5-slim
WORKDIR /root
RUN apt update && apt install -y libsodium-dev libglib2.0-dev libpq-dev
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

ENV LANG C.UTF-8
ENTRYPOINT ["bundle", "exec", "ruby", "bin/fumimi"]
