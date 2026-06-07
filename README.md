- name: Extract proot from Termux apt
  run: |
    echo "Downloading Termux proot .deb..."
    
    # Try multiple mirrors with retry logic
    MIRRORS=(
      "https://packages.termux.dev/apt/termux-main/pool/main/p/proot/proot_5.1.107.76_aarch64.deb"
      "https://plug-mirror.rcac.purdue.edu/termux/apt/termux-main/pool/main/p/proot/proot_5.1.107-65_aarch64.deb"
      "https://mirror.termux.aryadytm.id/apt/termux-main/pool/main/p/proot/proot_5.1.107-65_aarch64.deb"
      "https://termux.mentality.rip/termux-main/pool/main/p/proot/proot_5.1.107-65_aarch64.deb"
    )
    
    DOWNLOADED=false
    for mirror in "${MIRRORS[@]}"; do
      if wget -q --timeout=30 --tries=3 "$mirror" -O proot.deb; then
        echo "Successfully downloaded from: $mirror"
        DOWNLOADED=true
        break
      fi
      echo "Mirror failed: $mirror, trying next..."
    done
    
    if [ "$DOWNLOADED" = false ]; then
      echo "Failed to download from all mirrors"
      exit 1
    fi

    echo "Extracting proot binary..."
    mkdir -p proot_extract
    cd proot_extract
    ar x ../proot.deb
    tar xf data.tar.xz
    PROOT_BIN=$(find . -name "proot" -type f | head -1)
    echo "Found proot at: ${PROOT_BIN}"
    cp "${PROOT_BIN}" ../proot-aarch64
    cd ..

    # Verify it's a valid ELF binary
    file proot-aarch64
    ls -lh proot-aarch64
