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
    && apt-mark manual dvisvgm \
    && rm -rf /var/lib/apt/lists/*

# ── Stage 2: Python packages ──────────────────────────────────────────────────
# pip sees python3-cairo, python3-numpy, python3-pillow already installed
# and skips reinstalling them. Only manimpango needs compilation.
# Everything else in Manim's dependency tree gets prebuilt glibc wheels.
RUN pip3 install --break-system-packages --no-cache-dir \
    manimpango \
    manim

# ── Stage 3: Aggressive cleanup to minimize archive size ──────────────────────
RUN \
    # Remove Ghostscript — Manim doesn't use it, saves ~80MB
    apt-get remove -y --auto-remove ghostscript libgs10 2>/dev/null || true \
    \
    # Remove build tools
    && apt-get remove -y build-essential python3-dev \
        libcairo2-dev libpango1.0-dev libgirepository1.0-dev pkg-config \
    && apt-get autoremove -y \
    \
    # Remove all documentation
    && rm -rf /usr/share/doc \
    && rm -rf /usr/share/man \
    && rm -rf /usr/share/info \
    && rm -rf /usr/share/lintian \
    && rm -rf /usr/share/bug \
    \
    # Remove ALL locale data except C/POSIX
    && find /usr/share/locale -mindepth 1 -maxdepth 1 \
       ! -name "C" ! -name "C.UTF-8" ! -name "POSIX" \
       -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /usr/lib/locale \
    \
    # Remove Poppler CMap data (caused extraction errors, Manim doesn't need it)
    && rm -rf /usr/share/poppler \
    \
    # Aggressive TeX Live doc cleanup (~150MB)
    && find /usr/share/texlive -name "doc" -type d \
       -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/share/texmf -name "*.pdf" -delete 2>/dev/null || true \
    && find /usr/share/texmf -name "README*" -delete 2>/dev/null || true \
    \
    # Remove Python test suites and cache
    && find /usr -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr -name "__pycache__" -type d \
       -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/lib/python3 -name "test" -type d \
       -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/lib/python3 -name "tests" -type d \
       -exec rm -rf {} + 2>/dev/null || true \
    \
    # Strip debug symbols from binaries (~50MB)
    && find /usr/bin /usr/lib -name "*.so*" -type f \
       -exec strip --strip-unneeded {} + 2>/dev/null || true \
    && find /usr/bin -type f -executable \
       -exec strip --strip-unneeded {} + 2>/dev/null || true \
    \
    # Remove apt cache
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt \
    && rm -rf /root/.cache \
    && rm -rf /tmp/*

# Ensure dvisvgm is still present after aggressive cleanup
# (Some autoremove/cleanup sequences can remove it on certain images/architectures)
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

# ── Version marker ─────────────────────────────────────────────────────────[...]
ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version
