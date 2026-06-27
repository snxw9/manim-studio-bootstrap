# syntax=docker/dockerfile:1
# Manim Studio Bootstrap — Debian 12 (Bookworm) arm64

FROM --platform=linux/arm64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ── Combined Stage: Install, Build, and Clean in ONE Layer ────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python + Cairo + Pango + Utilities (NO TeX Live packages here!)
    python3 python3-pip python3-dev \
    python3-cairo python3-numpy python3-pillow \
    libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev \
    libglib2.0-0 libgirepository1.0-dev \
    pkg-config build-essential \
    ffmpeg ca-certificates bash wget curl perl xz-utils \
    fonts-dejavu fonts-noto-core \
    \
    && update-ca-certificates \
    \
    # ── Install Python Packages ──
    && pip3 install --break-system-packages --no-cache-dir manimpango manim \
    \
    # ── Install TinyTeX (Daily Release to match live CTAN) ──
    && echo "Downloading TinyTeX Minimal..." \
    && wget -qO- "https://yihui.org/tinytex/install-unx.sh" | TINYTEX_INSTALLER="TinyTeX-1" sh \
    && mv ~/.TinyTeX /opt/TinyTeX \
    # Clean up the script's default symlinks in the root home folder
    && rm -rf /root/bin \
    \
    # ── Install Specific Manim LaTeX Packages ──
    && echo "Installing required LaTeX packages for Manim..." \
    && /opt/TinyTeX/bin/*/tlmgr install \
        standalone preview doublestroke physics relsize calligra \
        wasysym ragged2e mathrsfs xcolor microtype dvisvgm \
        amsmath babel-english cm-super \
    # Use tlmgr's native symlink tool to put latex/dvisvgm in /usr/local/bin
    && /opt/TinyTeX/bin/*/tlmgr option sys_bin /usr/local/bin \
    && /opt/TinyTeX/bin/*/tlmgr path add \
    \
    # ── Aggressive Pre-Uninstall Cleanup ──
    # Strip binaries BEFORE removing build-essential (which provides binutils)
    && find /usr/local/lib/python* /usr/lib/python* -name "*.so*" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true \
    && find /usr/bin /usr/local/bin -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true \
    \
    # ── Remove Build Tools ──
    && apt-get remove -y --auto-remove \
        build-essential python3-dev \
        libcairo2-dev libpango1.0-dev libgirepository1.0-dev pkg-config xz-utils \
    && apt-get autoremove -y \
    \
    # ── Final Filesystem Sweep ──
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt \
    \
    # Remove documentation, man pages, and locales
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info \
    && find /usr/share/locale -mindepth 1 -maxdepth 1 \
       ! -name "C" ! -name "C.UTF-8" ! -name "POSIX" \
       -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /usr/lib/locale \
    \
    # Remove TinyTeX documentation and source files
    && rm -rf /opt/TinyTeX/texmf-dist/doc \
    && rm -rf /opt/TinyTeX/texmf-dist/source \
    \
    # Remove Python test suites and __pycache__ (Targeting /usr AND /usr/local)
    && find /usr /usr/local /opt -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr /usr/local /opt -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/lib/python* /usr/local/lib/python* -name "test" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/lib/python* /usr/local/lib/python* -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true \
    \
    # Clean temporary directories
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
