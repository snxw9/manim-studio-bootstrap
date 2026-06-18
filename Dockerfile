# syntax=docker/dockerfile:1
# Manim Studio Bootstrap — Debian 12 (Bookworm) arm64
# Multi-stage build: compile manimpango wheel in a builder stage and produce
# a small runtime image that only contains runtime libs and TeX.

# ---- builder: build binary wheels that require compilation ----
FROM --platform=linux/arm64 debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    WHEEL_DIR=/wheels

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev build-essential \
    pkg-config libcairo2-dev libpango1.0-dev libglib2.0-dev libgirepository-1.0-dev \
    python3-cairo python3-numpy python3-pillow \
    ca-certificates wget curl \
    && rm -rf /var/lib/apt/lists/*

# Ensure pip tooling and create wheel dir
RUN pip3 install --upgrade pip setuptools wheel && mkdir -p ${WHEEL_DIR}

# Build binary wheel(s) that need compilation. manimpango is the primary one.
# This places .whl files into /wheels for the final stage to pick up.
RUN pip3 wheel --no-cache-dir --wheel-dir ${WHEEL_DIR} manimpango

# Optionally collect other wheels (uncomment if you want to prefetch more):
# RUN pip3 wheel --no-cache-dir --wheel-dir ${WHEEL_DIR} manim


# ---- final: runtime image (smaller) ----
FROM --platform=linux/arm64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    WHEEL_DIR=/wheels

# Install only runtime system packages (no compilers/dev headers)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip \
    python3-cairo python3-numpy python3-pillow \
    libcairo2 libpango-1.0-0 libglib2.0-0 libgirepository-1.0-1 \
    ffmpeg \
    fonts-dejavu fonts-noto-core \
    texlive-latex-base texlive-latex-extra texlive-latex-recommended texlive-fonts-recommended \
    dvisvgm \
    ca-certificates bash wget curl \
    && apt-mark manual dvisvgm ffmpeg python3-cairo python3-numpy python3-pillow libcairo2 libpango-1.0-0 libglib2.0-0 libgirepository-1.0-1 \
    && rm -rf /var/lib/apt/lists/*

# Ensure dynamic loader and ld cache exist (required for proot on Android)
RUN set -eux; \
    # create /lib64 -> /lib for programs expecting it
    ln -sfn /lib /lib64 || true; \
    # ensure ld-linux-aarch64.so.1 points at the real loader
    if [ ! -e /lib/ld-linux-aarch64.so.1 ]; then \
      loader=$(ls /lib/aarch64-linux-gnu/ld-*.so 2>/dev/null | head -n1 || true); \
      if [ -n "$loader" ]; then ln -sf "$loader" /lib/ld-linux-aarch64.so.1; fi; \
    fi; \
    # populate ld cache
    ldconfig || true

# Copy wheels built in the builder stage
COPY --from=builder /wheels ${WHEEL_DIR}

# Install Python packages; allow pip to use local wheels first and fall back to PyPI
RUN pip3 install --break-system-packages --no-cache-dir --find-links ${WHEEL_DIR} \
    manimpango manim \
    && rm -rf ${WHEEL_DIR} /root/.cache/pip

# Aggressive cleanup to reduce size while keeping required runtime binaries
RUN rm -rf /usr/share/doc /usr/share/man /usr/share/info /usr/share/lintian /usr/share/bug \
    && find /usr/share/locale -mindepth 1 -maxdepth 1 \
       ! -name "C" ! -name "C.UTF-8" ! -name "POSIX" \
       -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /usr/lib/locale \
    && find /usr/share/texlive -name "doc" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/share/texmf -name "*.pdf" -delete 2>/dev/null || true \
    && find /usr/share/texmf -name "README*" -delete 2>/dev/null || true \
    && find /usr -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /var/cache/apt /root/.cache /tmp/*

# Verify presence of critical binaries and Python libs (clear diagnostics)
RUN set -euo pipefail; \
    for cmd in dvisvgm ffmpeg latex python3; do \
      if ! command -v "$cmd" >/dev/null 2>&1; then \
        echo "ERROR: required command missing: $cmd"; exit 1; \
      fi; \
    done; \
    python3 -c "import manim, cairo, manimpango, numpy; print('Python libs OK', manim.__version__)" ; \
    echo "All checks passed."

ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version
