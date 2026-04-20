FROM ruby:4.0.2 AS build
WORKDIR /tmp
RUN apt update && apt install -y ragel && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock fumimi-discord.gemspec ./
RUN gem install bundler:2.6.9
RUN bundle install

FROM ruby:4.0.2 AS fumimi
RUN apt update && apt install -y libsodium-dev libglib2.0-dev libpq-dev && rm -rf /var/lib/apt/lists/*
RUN useradd --user-group --create-home --shell /bin/bash fumimi
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=fumimi:fumimi . .

ENV LANG=C.UTF-8
ENV DISCORDRB_NONACL=1
USER fumimi
ENTRYPOINT ["bundle", "exec", "ruby", "bin/fumimi"]
