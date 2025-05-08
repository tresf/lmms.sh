#!/usr/bin/env bash

# LMMS installer, for bash
#
# This script was downloaded from https://github.com/lmms/lmms.sh and is part of the LMMS project
# Contribute to this script by visiting the above website and opening an issue or pull request
#
# Usage:
#
# ./install.sh [version] ("stable", "alpha", "nightly", "v1.2.2", etc)

set -e

SITE="https://lmms.io"

# TODO: Remove localhost when https://github.com/LMMS/lmms.io/pull/413 is merged
SITE="http://192.168.1.201:8000"

# For versioned downloads only
OWNER=lmms
REPO=lmms
JSON_URL="https://api.github.com/repos/$OWNER/$REPO/releases?per_page=100"

# Default to a local install
install_type="local"
build_type="stable"
build_qualifier=""
build_osver="" # TODO: implement this!
version="" # TODO: implement this!

print_help() {
  # Additional help text
  if [ ! -z "$1" ]; then
    echo "$1"
  fi
  # TODO: Actually add helpful text here
  echo "This is help (unfinished)"
  exit 1
}

curl_wget() {
  if command -v curl 2>&1 >/dev/null; then
    curl "$1"
  elif command -v wget 2>&1 >/dev/null; then
    wget -O - "$1"
  else
    echo "Script requires 'curl' or 'wget'"
    exit 1
  fi
}

# Parse args passed to this script
for arg in "$@"; do
  case "$arg" in
  stable*) build_type="stable"
    ;;
  alpha*) build_type="alpha"
    ;;
  beta*) build_type="beta"
    ;;
  nightly*) build_type="nightly"
    ;;
  pr*) build_type="pull-request" && pr="$arg"
    ;;
  v*) version="$arg"
    ;;
  -g|--global) install_type="global"
    ;;
  -h|--help) print_help
    ;;
  *) print_help "Option $arg did not match expected parameters"
    ;;
  esac
done

# Parse qualifier, if provided (e.g. "msvc")
for arg in "$@"; do
  case "$arg" in
  stable:*|alpha:*|beta:*|nightly:*|v*:*) build_qualifier="$(echo "$arg" | cut -d ':' -f 2)"
    ;;
  esac
done

# Determine URL for specified build_type
download_url=""
case "$build_type" in
pull-request)
  id="$(echo "$pr" | sed "s/pr//")"
  # validate pr
  if [ "$id" -eq "$id" ] 2>/dev/null; then
    true # ok
  else
     print_help "Pull-request '$id' is invalid"
  fi
  download_url="$SITE/download/pull-request/$id"
  ;;
*) download_url="$SITE/download"
  ;;
esac

get_os() {
  # OS must match lmms.io/lib/Os.php (lowercase)
  case "$OSTYPE" in
    cygwin*|msys*|win32*) echo "windows"
      ;;
    darwin*) echo "macos"
      ;;
    linux*) echo "linux"
      ;;
    *) echo "unknown"
      ;;
  esac
}

get_arch() {
  # OS must match lmms.io/lib/Platform.php/Architecture (lowercase)

  # Detect WoW environment
  if printenv 'ProgramFiles(Arm)' 2>&1 >/dev/null; then
    echo "arm64"
    return
  elif printenv 'ProgramFiles(x86)' 2>&1 >/dev/null; then
    echo "intel64"
    return
  fi

  case "$(uname -m)" in
    *arm64*|*aarch64*)
      echo "arm64"
      ;;
    *arm*)
      echo "arm"
      ;;
    *riscv64*)
      echo "riscv64"
      ;;
    *riscv*)
      echo "riscv"
      ;;
    *ppc64*)
      echo "ppc64"
      ;;
    *ppc*)
      echo "ppc"
      ;;
    *amd64*|*86_64*|*x64*)
      echo "intel64"
      ;;
    *86*)
      echo "intel"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

get_url_json() {
  https://api.github.com/repos/lmms/lmms/releases?per_page=100
}

get_url() {
  want_url="$1"
  want_os="$2"
  want_arch="$3"
  want_type="$4"
  want_qual="$5"
  want_osver="$6"

  if [ ! -z "$DEBUG" ]; then
    echo "Wanted: os: '$want_os', osver: '$want_osver', arch: '$want_arch', build: '$want_type', qual: '$want_qual'" >&2
  fi

  echo "Platform detected: $want_os:$want_arch" >&2
  echo "Build requested: $want_type" >&2
  if [ ! -z "$want_qual" ]; then
    echo "Build qualifier: $want_qual" >&2
  fi

  echo "Parsing download links at '$want_url'..." >&2
  lines="$(curl_wget "$want_url" |grep -e "/download/artifact" -e "/releases/download")"
  while IFS= read -r line; do
    # Attributes must match lmms.io/lib/Assets.php
    os="$(echo "$line" | grep -E -io 'data-os="[^\"]+"' | awk -F\" '{print$2}')"
    arch="$(echo "$line" | grep -E -io 'data-arch="[^\"]+"' | awk -F\" '{print$2}')"
    qual="$(echo "$line" | grep -E -io 'data-qualifier="[^\"]+"' | awk -F\" '{print$2}')"
    osver="$(echo "$line" | grep -E -io 'data-osver="[^\"]+"' | awk -F\" '{print$2}')"

    url="$(echo "$line" | grep -E -io 'href="[^\"]+"' | awk -F\" '{print$2}')"
    if [[ $url == /download/* ]]; then
      url="$SITE/$url" # fix relative links
    fi

    if [[ $1 == /pull-request/* ]]; then
      type="pull-request"
    else
      case "$url" in
        *-alpha*) type="alpha"
          ;;
        *-beta*) type="beta"
          ;;
        */artifact/*) type="nightly"
          ;;
        *) type="stable"
          ;;
        esac
    fi

    _debug="os: '$os', osver: '$osver', arch: '$arch', type: '$type', qual: '$qual', url: '$url'"

    # Handle optional params
    opt_qual=""
    if [ ! -z "$want_qual" ]; then
      opt_qual="$qual"
    fi
    opt_osver=""
    if [ ! -z "$want_osver" ]; then
      opt_osver="$osver"
    fi

    if [ "$want_os" = "$os" ] && [ "$want_arch" = "$arch" ] && [ "$want_type" = "$type" ] && [ "$want_qual" = "$opt_qual" ] && [ "$want_osver" = "$opt_osver" ]; then
      if [ ! -z "$DEBUG" ]; then
        echo "Using: $_debug" >&2
      fi
      echo "$url"
      return
    else
      if [ ! -z "$DEBUG" ]; then
        echo "Skipping: $_debug" >&2
      fi
    fi

  done <<< "$lines"
}

get_url_json() {
  want_url="$1"
  want_os="$2"
  want_arch="$3"
  want_type="$4"
  want_qual="$5"
  want_osver="$6"
  want_version="$7"

  echo "Parsing download links at '$want_url'..." >&2

  lines="$(curl_wget "$want_url")"

  urls=()
  while IFS= read -r line; do
    case $line in
      *"\"tag_name\":"*)
        tag_name="$(echo "$line" |cut -d '"' -f4 |tr -d '"'|tr -d ',' |tr -d ' ')"
        if [ "$want_version" = "$tag_name" ]; then
          found=true
        else
          if [ "$found" = true ]; then
            # Stop after the first found tag
            break
          fi
        fi
        ;;
      *"\"browser_download_url\":"*)
        if [ "$found" = true ]; then
          url="$(echo "$line" |cut -d '"' -f4 |tr -d '"'|tr -d ',' |tr -d ' ')"
          urls+=("$url")
          if [ ! -z "$DEBUG" ]; then
            echo "Found matching version: $url" >&2
          fi
        fi
        ;;
    esac
  done <<< "$lines"

  if [ "$found" != true ]; then
    return
  fi

  # Filter matching OSs
  os_urls=()
  for url in "${urls[@]}"; do
    case "$url" in
      *-lin|*.AppImage|*.run)
        os="linux"
      ;;
      *-mac|*.dmg|*.pkg)
        os="macos"
      ;;
      *-win|*.exe|*.msi)
        os="windows"
      ;;
    esac
    if [ "$want_os" = "$os" ]; then
      os_urls+=("$url")
      if [ ! -z "$DEBUG" ]; then
        echo "Found matching os: $url" >&2
      fi
    fi
  done

  # Filter again, but matching arch
  arch_urls=()
  for url in "${os_urls[@]}"; do
    case "$url" in
      *-riscv64*) arch="riscv64"
      ;;
      *-riscv*) arch="riscv"
      ;;
      *-arm64*|*-aarch64*) arch="arm64"
      ;;
      *-arm*) arch="arm"
      ;;
      *-x86_64|*-win64*|*-64*) arch="intel64"
      ;;
      *-*86*|*-win32*) arch="intel"
      ;;
      *)
        case "$want_version" in
          v1.3*)
            # macOS defaults to arm64 for 1.3 and higher
            if [ "$want_os" = "macos" ]; then
              arch="arm64"
            else
              arch="intel64"
            fi
          ;;
          *)
            arch="intel64"
          ;;
        esac
      ;;
    esac
    if [ "$want_arch" = "$arch" ]; then
      arch_urls+=("$url")
      if [ ! -z "$DEBUG" ]; then
        echo "Found matching arch: $url" >&2
      fi
    fi
  done

  # TODO: Filter remaining URLs and echo to the screen
}

if [ ! -z "$version" ]; then
  # Get versioned download URL from releases json
  want_url="$(get_url_json "$JSON_URL" "$(get_os)" "$(get_arch)" "$build_type" "$build_qualifier" "$build_osver" "$version")"
else
  # Get download URL from downloads page
  want_url="$(get_url "$download_url" "$(get_os)" "$(get_arch)" "$build_type" "$build_qualifier" "$build_osver")"
fi

if [ ! -z "$want_url" ]; then
  echo "Downloading $want_url..."
else
  echo "A download for this platform wasn't found.  For verbose output, export DEBUG=1 and run again."
fi
