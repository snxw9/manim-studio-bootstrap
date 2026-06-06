# syntax=docker/dockerfile:1
FROM --platform=linux/arm64 alpine:3.19

# ── Stage 1: Install everything ───────────────────────────────────────────────
RUN apk update && apk add --no-cache \
    # Python runtime
    python3 py3-pip \
    # Pre-built Python C extensions — avoids slow QEMU compilation
    py3-cairo py3-numpy py3-pillow \
    # Cairo + Pango runtime and headers (manimpango compiles against these)
    cairo cairo-dev \
    pango pango-dev \
    glib-dev \
    pkgconf \
    # Build tools for manimpango C extension
    build-base python3-dev \
    # FFmpeg for video encoding
    ffmpeg \
    # Fonts Manim uses
    font-dejavu \
    # LaTeX — correct Alpine 3.19 package names
    # texlive = base installation including latex + dvisvgm commands
    texlive \
    texlive-dvi \
    texmf-dist \
    # Utilities
    bash wget curl ca-certificates \
    && update-ca-certificates

# ── Stage 2: Install Python packages ─────────────────────────────────────────
# manimpango needs compilation against pango headers installed above.
# manim is mostly pure Python so installs quickly.
RUN pip3 install --break-system-packages --no-cache-dir \
    manimpango \
    manim

# ── Stage 3: Remove build tools to shrink the archive ────────────────────────
RUN apk del \
    build-base python3-dev \
    cairo-dev pango-dev glib-dev pkgconf \
    && rm -rf \
    /var/cache/apk/* \
    /root/.cache \
    /tmp/* \
    && find /usr/lib/python3* -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr/lib/python3* -name "__pycache__" -type d \
       -exec rm -rf {} + 2>/dev/null || true

# ── Stage 4: Verify everything works ─────────────────────────────────────────
RUN python3 -c "import manim; print('Manim', manim.__version__, 'OK')" \
    && python3 -c "import cairo; print('Cairo OK')" \
    && python3 -c "import manimpango; print('Manimpango OK')" \
    && latex --version | head -1 \
    && dvisvgm --version \
    && ffmpeg -version 2>&1 | head -1

# ── Default DNS ──────────────────────────────────────────────────────────────
RUN printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf

# ── Version marker ───────────────────────────────────────────────────────────
ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version
