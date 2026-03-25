# PromptOps Toolkit Development Container
# Base: PowerShell 7.4 on Ubuntu 22.04
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04 AS base

LABEL maintainer="valorisa"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

FROM base AS tools
RUN apt-get update && apt-get install -y shellcheck git curl jq && rm -rf /var/lib/apt/lists/*

FROM tools AS node
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs

FROM node AS python
RUN apt-get install -y python3 python3-pip && rm -rf /var/lib/apt/lists/*

FROM python AS final
WORKDIR /app
COPY . .
RUN pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck"

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-Command"]
# TODO(v2): Add non-root user for security hardening.
# TODO(v2): Add healthcheck instruction.
