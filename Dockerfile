FROM ruby:4.0.3 AS base
ENV LANG=C.UTF-8
ENV DISCORDRB_NONACL=1
RUN \
  useradd --user-group --create-home --shell /bin/bash fumimi && \
  apt-get install --update libsodium-dev libglib2.0-dev tini


FROM base AS build
RUN apt install -y ragel
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs $(nproc)


FROM base AS fumimi
WORKDIR /app
COPY --from=build --chown=fumimi:fumimi /usr/local/bundle /usr/local/bundle
COPY --chown=fumimi:fumimi . .

USER fumimi
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["bundle", "exec", "ruby", "bin/fumimi"]
