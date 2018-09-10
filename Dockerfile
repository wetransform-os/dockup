FROM debian:jessie-slim
LABEL maintainer="Simon Templer <simon@wetransform.to>"

RUN apt-get update \
&& apt-get install -y --no-install-recommends cron python-pip curl postfix \
&& pip install awscli \
&& apt-get autoclean -y \
&& apt-get autoremove -y \
&& rm -rf /usr/share/locale/* \
&& rm -rf /var/cache/debconf/*-old \
&& rm -rf /var/lib/apt/lists/* \
&& rm -rf /usr/share/doc/*

COPY ./scripts /dockup/
RUN chmod 755 /dockup/*.sh
CMD ["/dockup/run.sh"]

ENV PATHS_TO_BACKUP auto
ENV BACKUP_NAME backup
ENV RESTORE false
ENV RESTORE_TAR_OPTION --preserve-permissions
ENV NOTIFY_BACKUP_SUCCESS false
ENV NOTIFY_BACKUP_FAILURE false
ENV BACKUP_TAR_TRIES 5
ENV BACKUP_TAR_RETRY_SLEEP 30
ENV DOCKUP_MODE aws

# aws
ENV S3_BUCKET_NAME docker-backups.example.com
ENV AWS_ACCESS_KEY_ID **DefineMe**
ENV AWS_SECRET_ACCESS_KEY **DefineMe**
ENV AWS_DEFAULT_REGION us-east-1

# local
ENV LOCAL_TARGET /dockup/target
RUN mkdir $LOCAL_TARGET

WORKDIR /dockup
