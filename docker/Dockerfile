# Dockerfile for reusable dependency management tooling.
# This image is designed to run against arbitrary host project roots mounted to /workspace.

ARG PYTHON_VERSION=3.13-slim
FROM python:${PYTHON_VERSION}

RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    build-essential \
    dos2unix \
    findutils \
    sed \
    && rm -rf /var/lib/apt/lists/*

ARG USER_ID=1000
ARG GROUP_ID=1000
RUN addgroup --gid ${GROUP_ID} devuser && \
    adduser --disabled-password --gecos '' --uid ${USER_ID} --gid ${GROUP_ID} devuser

USER devuser

ENV PIPX_HOME=/home/devuser/.local/pipx
ENV PIPX_BIN_DIR=/home/devuser/.local/bin
ENV PATH=/home/devuser/.local/bin:${PATH}

RUN pip install --user pipx && pipx ensurepath
RUN pipx install pdm && \
    pipx install uv && \
    pipx install poetry && \
    pipx install pipenv

RUN pdm config use_uv true

COPY scripts/dev-setup.sh /opt/core-pdm-manager/dev-setup.sh
COPY scripts/internal /opt/core-pdm-manager/internal
RUN chmod +x /opt/core-pdm-manager/dev-setup.sh

WORKDIR /workspace

CMD ["/bin/bash"]

# Dockerfile for reusable dependency management tooling.
# This image is designed to run against arbitrary host project roots mounted to /workspace.

ARG PYTHON_VERSION=3.13-slim
FROM python:${PYTHON_VERSION}

RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    build-essential \
    dos2unix \
    findutils \
    sed \
    && rm -rf /var/lib/apt/lists/*

ARG USER_ID=1000
ARG GROUP_ID=1000
RUN addgroup --gid ${GROUP_ID} devuser && \
    adduser --disabled-password --gecos '' --uid ${USER_ID} --gid ${GROUP_ID} devuser

USER devuser

ENV PIPX_HOME=/home/devuser/.local/pipx
ENV PIPX_BIN_DIR=/home/devuser/.local/bin
ENV PATH=/home/devuser/.local/bin:${PATH}

RUN pip install --user pipx && pipx ensurepath
RUN pipx install pdm && \
    pipx install uv && \
    pipx install poetry && \
    pipx install pipenv

RUN pdm config use_uv true

USER root

COPY scripts/dev-setup.sh /opt/core-pdm-manager/dev-setup.sh
COPY scripts/internal /opt/core-pdm-manager/internal
RUN chmod +x /opt/core-pdm-manager/dev-setup.sh

RUN chown -R devuser:devuser /opt/core-pdm-manager

USER devuser

WORKDIR /workspace

CMD ["/bin/bash"]
