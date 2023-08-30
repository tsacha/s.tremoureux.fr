FROM alpine:latest as builder
MAINTAINER Sacha Trémoureux <sacha@tremoureux.fr>

COPY . /data/
RUN \
  apk -u --no-cache add hugo git && \
  git clone --single-branch https://github.com/tsacha/notsohyde.git /data/themes/not-so-hyde && \
  cd /data && hugo


FROM caddy
COPY --from=builder /data/public /usr/share/caddy
