# Manim Studio Bootstrap

A pre-built Debian-based rootfs environment optimized for running **Manim (Community Edition)** on Android devices under Termux and PRoot.

---

## 🚀 Why Debian instead of Alpine?

While Alpine Linux is often preferred for lightweight containers, it presents severe limitations for scientific Python environments:
* **musl libc vs glibc:** Alpine uses `musl libc`, which is incompatible with standard pre-compiled Python wheels.
* **Compilation Overhead:** On Alpine, `pip` must compile scientific packages (like `numpy`, `pillow`, `pycairo`, and `manimpango`) from source. Under QEMU emulation, this process is extremely slow and fragile.
* **Debian Advantage:** By using **Debian 12 (Bookworm)**, we leverage `glibc` compatibility to download pre-built wheels instantly, providing a fast, reliable, and consistent environment.

---

## 📦 What's Included

The bootstrap archive packages a complete Debian system tailored for Manim:
* **Debian 12 (Bookworm) Slim** (`arm64` / `aarch64`)
* **Python 3.11** + **Manim Community Edition** (v0.18.1)
* **Pre-compiled libraries:** `libcairo2`, `libpango-1.0`, `pycairo`, `manimpango`
* **LaTeX Environment (TeX Live):**
  * `texlive-latex-base` & `texlive-latex-extra`
  * `texlive-latex-recommended` & `texlive-fonts-recommended`
  * `texlive-science` & `dvisvgm` (for rendering math formulas to SVGs)
* **Multimedia:** `ffmpeg` for rendering MP4 animations
* **Fonts:** DejaVu and Noto core fonts for proper text rendering

---

## 🛠️ Build Pipeline & Optimizations

The rootfs is constructed and archived via GitHub Actions (`build.yml`). Key optimizations include:

### 1. Absolute Symlink Conversion
Android's `tar` utility and filesystem structure reject absolute symlinks (e.g., links pointing to `/usr/share/...` instead of a relative destination).
During the build, a high-performance inline Python script recursively scans the rootfs and resolves/re-links all absolute symlinks to relative targets in milliseconds, replacing slower multi-process shell loops.

### 2. High-Performance Archiving & Compression
* **Multi-threaded Compression (`pigz`):** The workflow installs and utilizes `pigz` (Parallel Implementation of GZip) to archive the rootfs, maximizing multi-core CPU usage on GitHub runners for significantly faster packaging.
* **No `--dereference`:** We strictly avoid the `--dereference` flag, which instructs `tar` to follow every symlink and copy the actual file content. Since TeX Live contains tens of thousands of symlinks, using `--dereference` would cause the archive size to explode to over 20GB.
* **`--hard-dereference`:** Only hard links are dereferenced, preserving regular symlinks.
* **Reduced Archive Size:** Keeps the compressed `tar.gz` archive size down to approximately ~400MB.

### 3. Build Caching & Single-Layer Cleanup
* **GitHub Actions Cache:** Docker Buildx cache sharing is enabled using the `gha` cache backend (via `cache-from` and `cache-to` arguments), caching reusable layers on GitHub's infrastructure to speed up subsequent builds.
* **Combined Installation, Build, and Cleanup:** The system package installation, Python package compilation (such as compiling `manimpango`), and aggressive file cleanup are executed within a single, unified `RUN` layer in the `Dockerfile`.
* **Zero Residual Build Overhead:** This prevents compilers (`build-essential`, `python3-dev`), package headers (`libcairo2-dev`, `libpango1.0-dev`, etc.), and intermediate pip build/cache artifacts from persisting in the final layer, ensuring the exported rootfs is minimal and the build environment footprint is optimized.

---

## 📄 Manifest Metadata

A `bootstrap-manifest.json` file is generated alongside each release, containing:
* Version and architecture (`aarch64`)
* Checksums (SHA256) of the archive and `proot` binary
* Detailed changelogs
* Build timestamps

This manifest is consumed by downstream apps to verify and automate bootstrap downloads.

