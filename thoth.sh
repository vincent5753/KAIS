#!/bin/bash

echo "[info] running preflight checks!"

os_detect() {
arch=$(uname -m)
echo "${arch}"

case "${arch}" in
  x86_64)
    echo "amd64"
    ;;
  arm64)
    echo "arm64"
    ;;
  aarch64)
    echo "arm64"
    ;;
  *)
    echo "unknow arch"
    ;;
esac
# TDL Platform / Distro
}

os_detect