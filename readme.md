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
During the build, a post-processing step converts all absolute symlinks inside the rootfs to relative paths:
```bash
find . -type l | while IFS= read -r link; do
  target=$(readlink "$link")
  if [[ "$target" == /* ]]; then
    # Converts absolute targets to relative targets relative to the link's directory
    ...
  fi
done
```

### 2. High-Performance Archiving
* **No `--dereference`:** We strictly avoid the `--dereference` flag, which instructs `tar` to follow every symlink and copy the actual file content. Since TeX Live contains tens of thousands of symlinks, using `--dereference` would cause the archive size to explode to over 20GB.
* **`--hard-dereference`:** Only hard links are dereferenced, preserving regular symlinks.
* **Reduced Archive Size:** Keeps the compressed `tar.gz` archive size down to approximately ~400MB.

---

## 📄 Manifest Metadata

A `bootstrap-manifest.json` file is generated alongside each release, containing:
* Version and architecture (`aarch64`)
* Checksums (SHA256) of the archive and `proot` binary
* Detailed changelogs
* Build timestamps

This manifest is consumed by downstream apps to verify and automate bootstrap downloads.