# The Dockerfile path on an image that already has its user, as Apache Airflow's does:
# uid 50000 with root as its primary group, no group named after it, and a home that
# holds the image's own files. The install has to work for that user and leave those
# files alone; root-owned is there to show it does.
FROM python:3.12-bookworm

RUN useradd -u 50000 -g 0 -m -s /bin/bash app \
    && install -o root -g root -m 644 /dev/null /home/app/root-owned

COPY src/dx /tmp/dx
RUN USERNAME=app AWS=false GH=false VAULT=false KUBECTL=false OPSSHSIGN=false bash /tmp/dx/install.sh \
    && rm -rf /tmp/dx

COPY test/dockerfile-existing-user/verify.sh /verify.sh

USER app
CMD ["bash", "/verify.sh"]
