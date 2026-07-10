# syntax=docker/dockerfile:1
# Manim Studio Bootstrap — Debian 12 (Bookworm) arm64

FROM --platform=linux/arm64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/TinyTeX/bin/aarch64-linux:${PATH}"

# ── Combined Stage: Install everything (gcc still present, needed below) ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev \
    python3-cairo \
    libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev \
    libpangocairo-1.0-0 \
    libglib2.0-0 libgirepository1.0-dev \
    pkg-config build-essential \
    ca-certificates bash wget curl perl xz-utils \
    fonts-dejavu fonts-noto-core \
    \
    && update-ca-certificates \
    \
    # ── Static FFmpeg (bypasses ~150MB of X11 GUI bloat) ──
    && echo "Downloading BtbN Static FFmpeg for ARM64..." \
    && wget -qO ffmpeg.tar.xz "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz" \
    && mkdir ffmpeg-temp \
    && tar -xf ffmpeg.tar.xz -C ffmpeg-temp --strip-components=1 \
    && cp ffmpeg-temp/bin/ffmpeg ffmpeg-temp/bin/ffprobe /usr/local/bin/ \
    && rm -rf ffmpeg.tar.xz ffmpeg-temp \
    \
    # ── Python packages ──
    && pip3 install --break-system-packages --no-cache-dir manimpango manim \
    \
    # ── TinyTeX (Daily Release Direct Tarball) ──
    && echo "Downloading Daily TinyTeX Minimal..." \
    && wget -qO tinytex.tar.xz "https://github.com/rstudio/tinytex-releases/releases/download/daily/TinyTeX-1-linux-arm64.tar.xz" \
    && mkdir -p /opt/TinyTeX \
    && tar -xf tinytex.tar.xz -C /opt/TinyTeX --strip-components=1 \
    && rm tinytex.tar.xz \
    \
    # ── LaTeX packages Manim needs ──
    && echo "Installing required LaTeX packages for Manim..." \
    && /opt/TinyTeX/bin/aarch64-linux/tlmgr update --self \
    # Swapped "mathrsfs" for "jknapltx rsfs" to fix the repository naming error
    && /opt/TinyTeX/bin/aarch64-linux/tlmgr install \
        standalone preview doublestroke physics relsize calligra \
        wasysym ragged2e jknapltx rsfs xcolor microtype dvisvgm \
        amsmath babel-english cm-super \
    && /opt/TinyTeX/bin/aarch64-linux/tlmgr path add \
    \
    # ── Safe cleanup that doesn't touch gcc yet ──
    && rm -rf /usr/local/lib/python*/dist-packages/scipy/datasets \
    && rm -f /usr/local/bin/ffprobe

# ── Build statx() compatibility shim ──────────────────────────────────────
# glibc >= 2.28 tries statx() first for os.stat(). PRoot's statx()
# translation has a gap that breaks CPython's import machinery when
# scanning directories to locate C-extension modules (cairo, manimpango).
# This LD_PRELOAD shim redirects statx() through fstatat(), which PRoot
# handles correctly.
#
# Shipped as its own file and COPY'd in — no heredoc anywhere in this
# Dockerfile, which avoids BuildKit's parser treating heredoc closing
# delimiters as the end of a backslash-continued RUN instruction.
COPY statx_shim.c /tmp/statx_shim.c

RUN gcc -shared -fPIC -O2 -o /usr/local/lib/statx_shim.so /tmp/statx_shim.c \
    && rm -f /tmp/statx_shim.c \
    && echo "statx shim built:" \
    && ls -la /usr/local/lib/statx_shim.so

# ── Remove Build Tools + Final Filesystem Sweep ───────────────────────────
# gcc and /usr/lib/gcc are removed here — AFTER the shim above, since the
# shim compile needs gcc's internal cc1/headers that live in /usr/lib/gcc.
RUN apt-get purge -y --auto-remove \
        build-essential gcc g++ cpp make python3-dev \
        libcairo2-dev libpango1.0-dev libgirepository1.0-dev pkg-config xz-utils \
    && apt-get autoremove -y \
    && rm -rf /usr/lib/gcc \
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

# Persist TinyTeX PATH into the rootfs so it survives docker export
RUN echo 'export PATH="/opt/TinyTeX/bin/aarch64-linux:$PATH"' >> /etc/profile \
    && echo 'PATH="/opt/TinyTeX/bin/aarch64-linux:$PATH"' >> /etc/environment

# ── Verify everything is working ──────────────────────────────────────────
RUN echo "Testing Cairo..." && python3 -c "import cairo; print('Cairo OK')" \
    && echo "Testing Manimpango..." && python3 -c "import manimpango; print('Manimpango OK')" \
    && echo "Testing NumPy..." && python3 -c "import numpy; print('NumPy', numpy.__version__, 'OK')" \
    && echo "Testing Manim..." && python3 -c "import manim; print('Manim', manim.__version__, 'OK')" \
    && echo "Testing LaTeX..." && latex --version | head -1 \
    && echo "Testing Dvisvgm..." && dvisvgm --version \
    && echo "Testing FFmpeg..." && ffmpeg -version 2>&1 | head -1 \
    && echo "Testing statx shim exists..." && ls -la /usr/local/lib/statx_shim.so \
    && echo "All checks passed."

# ── Version marker ─────────────────────────────────────────────────────────
ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version
