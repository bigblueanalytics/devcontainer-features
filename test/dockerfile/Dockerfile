# The Dockerfile path compose-backed devcontainers use: install.sh run as root during
# the build, options as env vars, no devcontainer CLI involved. The base is the one
# occam-temporal-etl's dev image builds from.
FROM python:3.12-bookworm

COPY src/dx /tmp/dx
RUN USERNAME=vscode HELM=true bash /tmp/dx/install.sh \
    && rm -rf /tmp/dx

COPY test/dockerfile/verify.sh /verify.sh

USER vscode
CMD ["bash", "/verify.sh"]
