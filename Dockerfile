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
    # (ffmpeg is removed from here to stop X11 GUI bloat)
    python3 python3-pip python3-dev \
    python3-cairo \
    libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev \
    libglib2.0-0 libgirepository1.0-dev \
    pkg-config build-essential \
    ca-certificates bash wget curl perl xz-utils \
    fonts-dejavu fonts-noto-core \
    \
    && update-ca-certificates \
    \
    # ── Install BtbN Static FFmpeg (Bypasses ~150MB of GUI bloat) ──
    && echo "Downloading BtbN Static FFmpeg for ARM64..." \
    && wget -qO ffmpeg.tar.xz "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz" \
    && mkdir ffmpeg-temp \
    && tar -xf ffmpeg.tar.xz -C ffmpeg-temp --strip-components=1 \
    && cp ffmpeg-temp/bin/ffmpeg ffmpeg-temp/bin/ffprobe /usr/local/bin/ \
    && rm -rf ffmpeg.tar.xz ffmpeg-temp \
    \
    # ── Install Python Packages ──
    && pip3 install --break-system-packages --no-cache-dir manimpango manim \
    \
    # ── Install TinyTeX Minimal ──
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
        amsmath babel-english cm-super \
    \
    # ── THE SAFE CLEANUP ──
    # ONLY remove safe Python dummy datasets (LLVM and dri are kept safe!)
    && rm -rf /usr/local/lib/python*/dist-packages/scipy/datasets \
    \
    # Remove GCC compiler directory — runtime libs (libstdc++, libgcc_s) are
    # in aarch64-linux-gnu/ and are unaffected. This removes compiler plugins only.
    && rm -rf /usr/lib/gcc \
    \
    # Remove ffprobe — Manim only uses ffmpeg for video encoding
    && rm -f /usr/local/bin/ffprobe

# ── Build statx() compatibility shim ──
# glibc >= 2.28 tries statx() first for os.stat(). PRoot's statx()
# translation has a gap that breaks CPython's import machinery when
# scanning directories to locate C-extension modules (cairo, manimpango).
# This LD_PRELOAD shim redirects statx() through fstatat(), which PRoot
# handles correctly.
#
# Must be its own RUN — heredocs cannot be mixed with && continuation
# chains in the same RUN instruction (that was the parse error above).
RUN <<'SHIMSCRIPT'
set -e
mkdir -p /tmp/shim
cd /tmp/shim
cat > statx_shim.c << 'CEOF'
#define _GNU_SOURCE
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <fcntl.h>
#include <string.h>

int statx(int dirfd, const char *pathname, int flags,
          unsigned int mask, struct statx *statxbuf) {
    struct stat st;
    int fstatat_flags = 0;
    if (flags & AT_SYMLINK_NOFOLLOW) fstatat_flags |= AT_SYMLINK_NOFOLLOW;
    if (flags & AT_EMPTY_PATH) fstatat_flags |= AT_EMPTY_PATH;
    if (fstatat(dirfd, pathname, &st, fstatat_flags) != 0) {
        return -1;
    }
    memset(statxbuf, 0, sizeof(*statxbuf));
    statxbuf->stx_mask = STATX_BASIC_STATS;
    statxbuf->stx_blksize = (unsigned int)st.st_blksize;
    statxbuf->stx_nlink = (unsigned int)st.st_nlink;
    statxbuf->stx_uid = st.st_uid;
    statxbuf->stx_gid = st.st_gid;
    statxbuf->stx_mode = st.st_mode;
    statxbuf->stx_ino = st.st_ino;
    statxbuf->stx_size = (unsigned long long)st.st_size;
    statxbuf->stx_blocks = (unsigned long long)st.st_blocks;
    statxbuf->stx_atime.tv_sec = st.st_atime;
    statxbuf->stx_mtime.tv_sec = st.st_mtime;
    statxbuf->stx_ctime.tv_sec = st.st_ctime;
    statxbuf->stx_rdev_major = major(st.st_rdev);
    statxbuf->stx_rdev_minor = minor(st.st_rdev);
    statxbuf->stx_dev_major = major(st.st_dev);
    statxbuf->stx_dev_minor = minor(st.st_dev);
    return 0;
}
CEOF
gcc -shared -fPIC -O2 -o statx_shim.so statx_shim.c
mkdir -p /usr/local/lib
cp statx_shim.so /usr/local/lib/statx_shim.so
cd /
rm -rf /tmp/shim
echo "statx shim built:"
ls -la /usr/local/lib/statx_shim.so
SHIMSCRIPT

# ── Remove Build Tools + Final Filesystem Sweep ──
# (unchanged from before — just isolated as its own RUN, no heredoc involved)
RUN rm -rf /usr/local/lib/python*/dist-packages/scipy/datasets \
    && apt-get purge -y --auto-remove \
        build-essential gcc g++ cpp make python3-dev \
        libcairo2-dev libpango1.0-dev libgirepository1.0-dev pkg-config xz-utils \
    && apt-get autoremove -y \
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

# ── Stage 2: Verify everything is working ────────────────────────────────────
RUN echo "Testing Cairo..." && python3 -c "import cairo; print('Cairo OK')" \
    && echo "Testing Manimpango..." && python3 -c "import manimpango; print('Manimpango OK')" \
    && echo "Testing NumPy..." && python3 -c "import numpy; print('NumPy', numpy.__version__, 'OK')" \
    && echo "Testing Manim..." && python3 -c "import manim; print('Manim', manim.__version__, 'OK')" \
    && echo "Testing LaTeX..." && latex --version | head -1 \
    && echo "Testing Dvisvgm..." && dvisvgm --version \
    && echo "Testing FFmpeg..." && ffmpeg -version 2>&1 | head -1 \
    && echo "All checks passed."

# ── Version marker ─────────────────────────────────────────────────────────
ARG BOOTSTRAP_VERSION=unknown
RUN echo "${BOOTSTRAP_VERSION}" > /etc/manim-bootstrap-version
