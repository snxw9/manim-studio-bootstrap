# syntax=docker/dockerfile:1
# Manim Studio Bootstrap — Debian 12 (Bookworm) arm64
#
# Why Debian instead of Alpine:
#   Alpine uses musl libc. Python packages ship prebuilt wheels for glibc only.
#   On Alpine, pip compiles everything from source — slow under QEMU, fragile.
#   On Debian (glibc), pip downloads ready-made wheels — fast and reliable.

FROM --platform=linux/arm64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ── Stage 1, 2 & 3 Combined: Install, Build, and Clean in ONE Layer ────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python runtime + headers
    python3 python3-pip python3-dev \
    # Pre-built Python C extensions
    python3-cairo python3-numpy python3-pillow \
    # Cairo + Pango runtime libs and headers
    libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev \
    libglib2.0-0 libgirepository1.0-dev \
    pkg-config build-essential \
    # Video encoding & Utilities
    ffmpeg ca-certificates bash wget curl \
    # Fonts
    fonts-dejavu fonts-noto-core \
    # TeX Live & DVI pipeline
    texlive-latex-base texlive-latex-extra texlive-latex-recommended \
    texlive-fonts-recommended texlive-science dvisvgm \
    \
    && update-ca-certificates \
    # Mark dvisvgm so it isn't caught in the upcoming autoremove crossfire
    && apt-mark manual dvisvgm \
    \
    # ── Install Python Packages ──
    && pip3 install --break-system-packages --no-cache-dir manimpango manim \
    \
    # ── Aggressive Cleanup ──
    # Remove compilers, headers, and unwanted packages
    && apt-get remove -y --auto-remove \
        build-essential python3-dev \
        libcairo2-dev libpango1.0-dev libgirepository1.0-dev pkg-config \
        ghostscript libgs10 \
    && apt-get autoremove -y \
    \
    # Clear apt cache
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt \
    \
    # Remove documentation, man pages, and locales
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info \
    && rm -rf /usr/share/lintian /usr/share/bug /usr/share/poppler \
    && find /usr/share/locale -mindepth 1 -maxdepth 1 \
       ! -name "C" ! -name "C.UTF-8" ! -name "POSIX" \
       -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /usr/lib/locale \
    \
    # Aggressive TeX Live doc cleanup
    && find /usr/share/texlive -name "doc" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/share/texmf -name "*.pdf" -delete 2>/dev/null || true \
    && find /usr/share/texmf -name "README*" -delete 2>/dev/null || true \
    \
    # Remove Python test suites and cache
    && find /usr -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/lib/python3 -name "test" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/lib/python3 -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true \
    \
    # Strip debug symbols from binaries
    && find /usr/bin /usr/lib -name "*.so*" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true \
    && find /usr/bin -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true \
    \
    # Final tmp/cache sweep
    && rm -rf /root/.cache /tmp/*

# Fallback: Ensure dvisvgm is still present (just in case apt dependency chains try to remove it)
RUN if ! command -v dvisvgm >/dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends dvisvgm && rm -rf /var/lib/apt/lists/*; \
    fi && apt-mark manual dvisvgm || true

# ── Stage 4: Verify everything is working ────────────────────────────────────
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
