FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install PyWebView OS dependencies for Linux (GTK and WebKit2)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    gcc \
    pkg-config \
    python3-dev \
    libgirepository-2.0-dev \
    libcairo2-dev \
    gir1.2-gtk-3.0 \
    gir1.2-webkit2-4.1 \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*
