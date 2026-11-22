FROM nextcloud:latest

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gnupg2 \
      ca-certificates \
      wget \
      smbclient \
      cifs-utils \
 && wget -qO- https://packages.sury.org/php/apt.gpg | apt-key add - \
 && echo "deb https://packages.sury.org/php/ bookworm main" \
      > /etc/apt/sources.list.d/sury-php.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends php-smbclient \
 && rm -rf /var/lib/apt/lists/*

USER www-data
