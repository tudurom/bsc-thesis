#!/usr/bin/env bash

set -euo pipefail

ORIGINAL_URL="${ORIGINAL_URL:-https://go.dev/dl/go1.22.3.linux-amd64.tar.gz}"
T_URL="${T_URL:-https://go.dev/dl/go1.21.10.linux-amd64.tar.gz}"

usage() {
  echo "Usage: $0 -n"
  echo
  echo "-n disables downloading."
}

log() {
  echo "[DDC] $@"
}

cmp2() {
  sha256sum "$1" "$2"
  local hash="$(sha256sum "$1" | awk '{print $1}')"
  (
    echo "$hash $1"
    echo "$hash $2"
  ) | sha256sum --check
}

if [[ "$#" -gt 1 ]]; then
  usage
  exit 1
fi

if [[ "$#" -eq 1 ]] && [[ "$1" != '-n' ]]; then
  usage
  exit 1
fi

DOWNLOAD=1

if [[ "$#" -eq 1 ]] && [[ "$1" = '-n' ]]; then
  DOWNLOAD=0
fi

if [[ "$DOWNLOAD" -ne 0 ]]; then
  log "Downloading Go release from $ORIGINAL_URL"
  wget --no-verbose -O '/tmp/go-original.tar.gz' "$ORIGINAL_URL"

  log "Downloading secondary (T) Go release from $T_URL"
  wget --no-verbose -O '/tmp/go-T.tar.gz' "$T_URL"
else
  log "Not downloading..."
fi

ORIGINAL_DIR="$(mktemp -d '/tmp/ddc-release-XXXXX')"
T_DIR="$(mktemp -d '/tmp/ddc-T-XXXXX')"

log "Untarring release to $ORIGINAL_DIR"
tar -xzf "/tmp/go-original.tar.gz" -C "$ORIGINAL_DIR"

log "Untarring T to $T_DIR"
tar -xzf "/tmp/go-T.tar.gz" -C "$T_DIR"

log "Creating copies"
cp --reflink=auto -R "$ORIGINAL_DIR/" "${ORIGINAL_DIR}-hackseed/"
cp --reflink=auto -R "$ORIGINAL_DIR/" "${ORIGINAL_DIR}-hack/"
cp --reflink=auto -R "$ORIGINAL_DIR/" "${ORIGINAL_DIR}-hack-regen/"
cp --reflink=auto -R "$ORIGINAL_DIR/" "${ORIGINAL_DIR}-compiled-with-T/"
cp --reflink=auto -R "$ORIGINAL_DIR/" "${ORIGINAL_DIR}-compiled-with-T-regen/"

log "Removing binaries from copies"
rm -vrf "${ORIGINAL_DIR}"-{hackseed,hack,hack-regen,compiled-with-T,compiled-with-T-regen}/go/{bin/*,pkg/tool/*}

log "Cleaning cache"
GOROOT="$ORIGINAL_DIR/go" PATH="$GOROOT/bin:$PATH" go clean -cache

log "Placing hack seed with evilgen"
GOROOT="$ORIGINAL_DIR/go" PATH="$GOROOT/bin:$PATH" \
  go run ./evilgen/main.go ./attack/syntax.go.tpl \
  > "${ORIGINAL_DIR}-hackseed/go/src/cmd/compile/internal/syntax/syntax.go"

log "Compiling seed compiler"
(
  cd "${ORIGINAL_DIR}-hackseed/go/src/"
  export GOROOT_BOOTSTRAP="$ORIGINAL_DIR/go"
  export GOROOT="${ORIGINAL_DIR}-hackseed/go"
  ./clean.bash || true
  ./make.bash
)

log "Compiling hacked compiler using seed compiler"
(
  cd "${ORIGINAL_DIR}-hack/go/src/"
  export GOROOT_BOOTSTRAP="${ORIGINAL_DIR}-hackseed/go"
  export GOROOT="${ORIGINAL_DIR}-hack/go"
  ./clean.bash || true
  ./make.bash
)

log "DDC PART 1: Compile A with A"
log "A = ${ORIGINAL_DIR}-hack"
(
  cd "${ORIGINAL_DIR}-hack-regen/go/src/"
  export GOROOT_BOOTSTRAP="${ORIGINAL_DIR}-hack/go"
  export GOROOT="${ORIGINAL_DIR}-hack-regen/go"
  ./clean.bash || true
  ./make.bash
)

log "Comparing hashes of A and regenerated A"
cmp2 "${ORIGINAL_DIR}"-{hack,hack-regen}"/go/pkg/tool/linux_amd64/compile"

log "DDC PART 2: Compile A with T"
(
  cd "${ORIGINAL_DIR}-compiled-with-T/go/src/"
  export GOROOT_BOOTSTRAP="$T_DIR/go"
  export GOROOT="${ORIGINAL_DIR}-compiled-with-T/go"
  ./clean.bash || true
  ./make.bash
)

log "DDC PART 3: Compile A with A_T (A of T)"
(
  cd "${ORIGINAL_DIR}-compiled-with-T-regen/go/src/"
  export GOROOT_BOOTSTRAP="${ORIGINAL_DIR}-compiled-with-T/go"
  export GOROOT="${ORIGINAL_DIR}-compiled-with-T-regen/go"
  ./clean.bash || true
  ./make.bash
)
log "Comparing hashes of A and A_A_T"
cmp2 "${ORIGINAL_DIR}"-{compiled-with-T-regen,hack-regen}"/go/pkg/tool/linux_amd64/compile"
