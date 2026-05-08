FROM caddy:2.11.2-builder AS builder

RUN xcaddy build \
    --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive

FROM caddy:2.11.2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
