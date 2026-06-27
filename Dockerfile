# syntax=docker/dockerfile:1
# Manim Studio Bootstrap — Debian 12 (Bookworm) arm64

FROM --platform=linux/arm64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/TinyTeX/bin/aarch64-linux:${PATH}"

# ── Combined Stage: Install, Build, and Clean in ONE Layer ────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Standard Python and rendering dependencies
    # (Notice: python3-numpy and python3-pillow are REMOVED to prevent double-installs)
    python3 python3-pip python3-dev \
    python3-cairo \
    libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev \
    libglib2.0-0 libgirepository1.0-dev \
    pkg-config build-essential \
    ffmpeg ca-certificates bash wget curl perl xz-utils \
    # Restored Noto fonts for wide character support
    fonts-dejavu fonts-noto-core \
    \
    && update-ca-certificates \
    \
    # ── Install Python Packages ──
    # Pip installs the exact wheels Manim wants (Single install, no duplicates)
    && pip3 install --break-system-packages --no-cache-dir manimpango manim \
    \
    # ── Install TinyTeX ──
    && echo "Downloading TinyTeX Minimal..." \
    && wget -qO- "https://yihui.org/tinytex/install-unx.sh" | TINYTEX_INSTALLER="TinyTeX-1" sh \
    && mv ~/.TinyTeX /opt/TinyTeX \
    && rm -rf /root/bin \
    \
    # ── Install Specific Manim LaTeX Packages ──
    && echo "Installing required LaTeX packages for Manim..." \
    && tlmgr install \
        standalone preview doublestroke physics relsize calligra \
        wasysym ragged2e mathrsfs xcolor microtype dvisvgm \
        # Restored cm-super font package
        amsmath babel-english cm-super \
    \
    # ── THE >100MB X-RAY CLEANUP ──
    # 1. Nuke LLVM/DRI hardware graphics drivers
    && rm -f /usr/lib/aarch64-linux-gnu/libLLVM-*.so* \
    && rm -rf /usr/lib/aarch64-linux-gnu/dri \
    \
    # 2. Delete SciPy/NumPy developer testing datasets & dummy files
    && rm -rf /usr/local/lib/python*/dist-packages/scipy/datasets \
    && find /usr/local/lib/python* -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/local/lib/python* -type d -name "test" -exec rm -rf {} + 2>/dev/null || true \
    \
    # 3. Strip debug symbols from heavy C-extensions (Safely shrinks .so binaries)
    && find /usr/local/lib/python* /usr/lib/python* -name "*.so*" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true \
    \
    # ── Remove Build Tools ──
    && apt-get purge -y --auto-remove \
        build-essential gcc g++ cpp make python3-dev \
        libcairo2-dev libpango1.0-dev libgirepository1.0-dev pkg-config xz-utils \
    && apt-get autoremove -y \
    \
    # ── Final Filesystem Sweep ──
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt \
    && rm -rf /var/log/apt/* /var/log/dpkg.log \
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info \
    && find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name "C" ! -name "C.UTF-8" ! -name "POSIX" -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /usr/lib/locale \
    && rm -rf /opt/TinyTeX/texmf-dist/doc \
    && rm -rf /opt/TinyTeX/texmf-dist/source \
    && find /usr /usr/local /opt -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr /usr/local /opt -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /root/.cache /tmp/*

# ── Stage 2: Verify everything is working ────────────────────────────────────
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

