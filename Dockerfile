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

# ── Stage 1: System packages ──────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    \
    # Python runtime + headers (headers needed only for manimpango compile)
    python3 python3-pip python3-dev \
    \
    # Pre-built Python C extensions — glibc wheels, no source compilation
    python3-cairo python3-numpy python3-pillow \
    \
    # Cairo + Pango runtime libs and headers (manimpango compiles against these)
    libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev \
    libglib2.0-0 \
    libgirepository1.0-dev \
    pkg-config \
    \
    # Compiler toolchain — only needed to build manimpango, removed after
    build-essential \
    \
    # Video encoding
    ffmpeg \
    \
    # Fonts Manim references
    fonts-dejavu fonts-noto-core \
    \
    # LaTeX for MathTex rendering
    # texlive-latex-base     → latex, pdflatex commands
    # texlive-latex-extra    → standalone, preview packages (Manim template needs these)
    # texlive-latex-recommended → amsmath, geometry, etc.
    # texlive-fonts-recommended → CM fonts, standard math fonts
    # texlive-science        → physics package
    # dvisvgm                → converts DVI to SVG (Manim's rendering pipeline)
    texlive-latex-base \
    texlive-latex-extra \
    texlive-latex-recommended \
    texlive-fonts-recommended \
    texlive-science \
    dvisvgm \
    \
    # Utilities
    ca-certificates bash wget curl \
    \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── Stage 2: Python packages ──────────────────────────────────────────────────
# pip sees python3-cairo, python3-numpy, python3-pillow already installed
# and skips reinstalling them. Only manimpango needs compilation.
# Everything else in Manim's dependency tree gets prebuilt glibc wheels.
RUN pip3 install --break-system-packages --no-cache-dir \
    manimpango \
    manim

# ── Stage 3: Remove build tools ───────────────────────────────────────────────
# The C compiler and dev headers are no longer needed after manimpango compiles.
# Runtime libraries (libcairo2, libpango-1.0-0) are kept — manimpango needs them.
RUN apt-get remove -y \
        build-essential python3-dev \
        libcairo2-dev libpango1.0-dev \
        libgirepository1.0-dev pkg-config \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/cache/apt/archives/* \
        /root/.cache \
        /tmp/* \
    && find /usr/lib/python3 -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr/lib/python3 -name "__pycache__" -type d \
       -exec rm -rf {} + 2>/dev/null || true

# ── Stage 4: Verify everything is working ────────────────────────────────────
RUN python3 -c "import manim; print('Manim', manim.__version__, 'OK')" \
    && python3 -c "import cairo; print('Cairo OK')" \
    && python3 -c "import manimpango; print('Manimpango OK')" \
    && python3 -c "import numpy; print('NumPy', numpy.__version__, 'OK')" \
    && latex --version | head -1 \
    && dvisvgm --version \
    && ffmpeg -version 2>&1 | head -1 \
    && echo "All checks passed."

# ── Default DNS ───────────────────────────────────────────────────────────────
RUN printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf

# ── Version marker ────────────────────────────────────────────────────────────
ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version
