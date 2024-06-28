#!/bin/bash

arch=`([[ $1 = "arm64" ]] && echo "aarch64" || echo $1)`
scversion='v0.10.0'

wget -qO- "https://github.com/koalaman/shellcheck/releases/download/${scversion?}/shellcheck-${scversion?}.linux.${arch?}.tar.xz" | tar -xJv
cp "shellcheck-${scversion}/shellcheck" /usr/local/bin
rm -rf "shellcheck-${scversion}"
shellcheck --version