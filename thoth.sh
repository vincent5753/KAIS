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

# Platform Detection
# ref: https://stackoverflow.com/questions/394230/how-to-detect-the-os-from-a-bash-script
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "On linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "On macOS"
elif [[ "$OSTYPE" == "cygwin" ]]; then
  echo "A computer is like air conditioning – it becomes useless when you open..."
elif [[ "$OSTYPE" == "msys" ]]; then
 echo "A computer is like air conditioning – it becomes useless when you open..."
elif [[ "$OSTYPE" == "win32" ]]; then
  echo "A computer is like air conditioning – it becomes useless when you open..."
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  echo "On freebsd"
else
  echo "Not supported OS?"
fi

# TDL: distro detection
}

os_detect
