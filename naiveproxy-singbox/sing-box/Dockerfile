FROM ghcr.io/sagernet/sing-box

RUN apk add --no-cache gettext

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

