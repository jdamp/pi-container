# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim

ARG PI_VERSION=latest
ARG QMD_VERSION=2.1.0
ARG TYPST_VERSION=0.14.2
ARG JUST_VERSION=1.40.0

# System packages
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
     bash \
     ca-certificates \
     chromium \
     curl \
     fontconfig \
     fonts-roboto \
     git \
     jq \
     make \
     openssh-client \
     perl \
     python3 \
     python3-pip \
     ripgrep \
     tar \
     unzip \
     vim \
     wget \
     xz-utils \
 && rm -rf /var/lib/apt/lists/*

# uv (Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Rename the UID-1000 user from `node` to `pi` with home /home/pi.
# /home/pi is expected to be mounted as persistent storage at runtime.
RUN sed -i 's|^node:|pi:|; s|:/home/node:|:/home/pi:|' /etc/passwd \
 && sed -i 's|^node:|pi:|' /etc/group \
 && rm -rf /home/node \
 && mkdir -p /home/pi \
 && chown -R 1000:1000 /home/pi

# typst
RUN wget -qO- "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" \
    | tar -xJf - --strip-components=1 -C /usr/local/bin/ "typst-x86_64-unknown-linux-musl/typst"

# just (not in Debian apt repos)
RUN wget -qO- "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xzf - -C /usr/local/bin/ just

# Pi tooling
RUN npm install -g "@mariozechner/pi-coding-agent@${PI_VERSION}" \
 && npm cache clean --force

# Install qmd separately so its native postinstall stays isolated from the pi CLI.
RUN npm install -g "@tobilu/qmd@${QMD_VERSION}" \
 && npm cache clean --force

# Fonts
COPY install-fonts.sh /tmp/install-fonts.sh
RUN chmod +x /tmp/install-fonts.sh && /tmp/install-fonts.sh && rm /tmp/install-fonts.sh

# `pi install` at runtime writes to a user-writable npm prefix under $HOME.
# Set this AFTER the root-level npm installs above so pi/qmd land in /usr/local
# (which survives a PVC mount on /home/pi).
ENV NPM_CONFIG_PREFIX=/home/pi/.npm-global \
    PATH=/home/pi/.npm-global/bin:/home/pi/.local/bin:/usr/local/bin:/usr/bin:/bin \
    HOME=/home/pi

RUN mkdir -p /home/pi/.npm-global /workspace \
 && chown -R 1000:1000 /home/pi

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER pi
WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD ["pi"]
