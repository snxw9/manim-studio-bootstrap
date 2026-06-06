# syntax=docker/dockerfile:1
# Builds a complete Alpine Linux arm64 rootfs with Manim pre-installed.
# Built under QEMU on GitHub Actions — all heavy native deps come from
# Alpine's pre-built arm64 packages to minimise compilation time.

FROM --platform=linux/arm64 alpine:3.19

# ── System packages ─────────────────────────────────────────────────────────
# Use pre-built Alpine packages wherever possible to avoid compiling under QEMU.
# py3-cairo    = pycairo (pre-built, avoids compiling against libcairo headers)
# py3-numpy    = numpy   (pre-built, avoids long Cython compilation)
# py3-pillow   = Pillow  (pre-built)
RUN apk update && apk add --no-cache \
    # Python runtime
    python3 py3-pip \
    # Pre-built Python C extensions
    py3-cairo py3-numpy py3-pillow \
    # Cairo and Pango runtime + headers (manimpango needs headers to compile)
    cairo pango \
    cairo-dev pango-dev \
    gobject-introspection-dev \
    pkgconfig \
    # Build tools (needed only for manimpango compilation, removed after)
    gcc musl-dev python3-dev \
    # Media
    ffmpeg \
    # Fonts
    font-dejavu font-noto \
    # LaTeX — Manim needs latex + dvisvgm for MathTex rendering
    texlive-full \
    texlive-xetex \
    # Utilities
    bash wget curl ca-certificates \
    && update-ca-certificates

# ── Python packages ─────────────────────────────────────────────────────────
# manimpango must compile from source (not in Alpine repos).
# manim is pure Python on top — fast to install.
RUN pip3 install --break-system-packages --no-cache-dir \
    manimpango \
    manim

# ── Post-install cleanup ──────────────────────────────────────────────────────
# Remove build tools and package cache to shrink the archive.
RUN apk del gcc musl-dev python3-dev \
    cairo-dev pango-dev gobject-introspection-dev pkgconfig \
    && rm -rf /var/cache/apk/* \
    && rm -rf /root/.cache \
    && find /usr/lib/python3* -name "*.pyc" -delete \
    && find /usr/lib/python3* -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# ── Verify ────────────────────────────────────────────────────────────
RUN python3 -c "import manim; print('Manim', manim.__version__, 'OK')" \
    && python3 -c "import cairo; print('Cairo OK')" \
    && python3 -c "import manimpango; print('Manimpango OK')" \
    && latex --version | head -1 \
    && dvisvgm --version \
    && ffmpeg -version | head -1

# ── DNS stub ───────────────────────────────────────────────────────────
# Default resolv.conf so the rootfs works immediately after extraction.
# BootstrapInstaller.kt will overwrite this if needed.
RUN echo "nameserver 8.8.8.8" > /etc/resolv.conf \
    && echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Keep a version marker inside the rootfs itself
ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version
