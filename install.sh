#!/usr/bin/env bash

set -e

SITE="https://lmms.io"

# TODO: Remove localhost when https://github.com/LMMS/lmms.io/pull/413 is merged
SITE="http://localhost:8000"

# Default to a local install
install_type="local"
build_type="stable"

print_help() {
  # Additional help text
  if [ ! -z "$1" ]; then
    echo "$1"
  fi
  # TODO: Actually add helpful text here
  echo "This is help (unfinished)"
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
  stable) build_type="stable"
    ;;
  alpha) build_type="alpha"
    ;;
  beta) build_type="beta"
    ;;
  nightly) build_type="nightly"
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
     exit 1
  fi
  download_url="$SITE/download/pull-request/$id"
  ;;
*) download_url="$SITE/download"
  ;;
esac

parse_downloads() {
  echo "Parsing download links at '$1'..."
  lines="$(curl_wget "$1" |grep -e "/download/artifact" -e "/releases/download")"
  #links="$(curl_wget "$MAIN_URL" |grep "/releases/download" | grep -E -io 'href="[^\"]+"' | awk -F\" '{print$2}')"
  #echo "$links"
  while IFS= read -r line; do
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

      echo "Download found:"
      echo "  os: $os"
      echo "  osver: $osver"
      echo "  arch: $arch"
      echo "  type: $type"
      echo "  qual: $qual"
      echo "  url: $url"
      echo ""
  done <<< "$lines"
}

parse_downloads "$download_url"