FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    restic \
    rclone \
    tzdata

WORKDIR /app

COPY backup.sh /usr/local/bin/config-backup
COPY include.txt /app/include.txt
COPY exclude.txt /app/exclude.txt

RUN chmod +x /usr/local/bin/config-backup

ENTRYPOINT ["config-backup"]
CMD ["daemon"]
