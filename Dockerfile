# syntax=docker/dockerfile:1
# Manim Studio Bootstrap — Debian 12 (Bookworm) arm64

# ── Stage 1: Build and Compile ──────────────────────────────────────────────
FROM --platform=linux/arm64 debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install build-time dependencies and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools & headers
    build-essential python3-dev \
    libcairo2-dev libpango1.0-dev libgirepository1.0-dev pkg-config \
    # Python + Cairo + NumPy + Pillow (installed as system packages to avoid compiling from scratch)
    python3 python3-pip python3-cairo python3-numpy python3-pillow \
    # Downloader & archivers
    ca-certificates wget xz-utils perl \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install python packages via pip
RUN pip3 install --break-system-packages --no-cache-dir manimpango manim

# Install TinyTeX (Deterministic ARM64 Release)
RUN echo "Downloading TinyTeX for ARM64..." \
    && wget -qO tinytex.tar.xz "https://github.com/rstudio/tinytex-releases/releases/download/v2026.06/TinyTeX-1-linux-arm64-v2026.06.tar.xz" \
    && mkdir -p /opt/TinyTeX \
    && tar -xf tinytex.tar.xz -C /opt/TinyTeX --strip-components=1 \
    && rm tinytex.tar.xz

# Install Specific Manim LaTeX Packages
RUN /opt/TinyTeX/bin/*/tlmgr install \
    standalone preview doublestroke physics relsize calligra \
    wasysym ragged2e mathrsfs xcolor microtype dvisvgm \
    amsmath babel-english cm-super

# Clean/Strip Builder binaries to minimize footprint before copying
RUN find /usr/local -name "*.so*" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true \
    && find /usr/local/bin -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true \
    && rm -rf /opt/TinyTeX/texmf-dist/doc \
    && rm -rf /opt/TinyTeX/texmf-dist/source \
    && find /usr/local -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr/local -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/local/lib/python* -name "test" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/local/lib/python* -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /usr/local/share/man/* \
    && rm -rf /usr/local/src/*

# ── Stage 2: Final Runtime Image ─────────────────────────────────────────────
FROM --platform=linux/arm64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install runtime packages only (NO compilers/headers)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python runtime and pre-built modules
    python3 python3-pip python3-cairo python3-numpy python3-pillow \
    # Libraries
    libcairo2 libpango-1.0-0 libglib2.0-0 \
    # Multimedia & utilities
    ffmpeg ca-certificates bash wget curl perl \
    # Fonts
    fonts-dejavu fonts-noto-core \
    && update-ca-certificates \
    # Aggressive Cleanup of Apt and Cache
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt \
    # Remove documentation, man pages, and locales to keep rootfs minimal
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info \
    && find /usr/share/locale -mindepth 1 -maxdepth 1 \
       ! -name "C" ! -name "C.UTF-8" ! -name "POSIX" \
       -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /usr/lib/locale \
    # Remove final Python cache/test files if any are generated
    && find /usr -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /root/.cache /tmp/*

# Copy TinyTeX and Python libraries from the builder stage
COPY --from=builder /opt/TinyTeX /opt/TinyTeX
COPY --from=builder /usr/local /usr/local

# Add TinyTeX binaries to path
RUN /opt/TinyTeX/bin/*/tlmgr path add

# ── Stage 3: Verification ──────────────────────────────────────────────────
RUN python3 -c "import manim; print('Manim', manim.__version__, 'OK')" \
    && python3 -c "import cairo; print('Cairo OK')" \
    && python3 -c "import manimpango; print('Manimpango OK')" \
    && python3 -c "import numpy; print('NumPy', numpy.__version__, 'OK')" \
    && latex --version | head -1 \
    && dvisvgm --version \
    && ffmpeg -version 2>&1 | head -1 \
    && echo "All checks passed."

# ── Version marker ───────────────────────────────────────────────────────────
ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version

