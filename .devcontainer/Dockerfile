FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install PyWebView OS dependencies for Linux
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    gcc \
    pkg-config \
    python3-dev \
    libnspr4 \
    libnss3 \
    libasound2t64 \
    libgbm1 \
    libxkbcommon-x11-0 \
    libxcb-cursor0 \
    libxkbfile1 \
    libgl1 \
    libegl1 \
    libopengl0 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxtst6 \
    libdbus-1-3 \
    libxcb-icccm4 \
    libxcb-keysyms1 \
    libxcb-shape0 \
    libxcb-xinerama0 \
    libwayland-cursor0 \
    libwayland-egl1 \
    libwayland-server0 \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*
