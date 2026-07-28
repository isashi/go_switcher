#!/usr/bin/env bash

# switch-go.sh - small helper to install and switch between Go versions.
# Compatible with Bash and Zsh, both when executed directly and when sourced.
#
# Optional configuration:
#   GO_SWITCH_ROOT    Directory where Go installations are stored. Default: $HOME/Sviluppo
#   GO_SWITCH_SYMLINK Symlink used as the stable GOROOT. Default: $GO_SWITCH_ROOT/go

_go_switch_is_sourced() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        case $ZSH_EVAL_CONTEXT in *:file:*) return 0;; esac
    else
        [ "${BASH_SOURCE[0]}" != "$0" ] 2>/dev/null && return 0
    fi
    return 1
}

_go_switch_finish() {
    local code="$1"
    if _go_switch_is_sourced; then
        return "$code"
    fi
    exit "$code"
}

_go_switch_usage() {
    cat <<'EOF'
Usage:
  goswitch <version>       Install if needed and switch to the selected version
  goswitch current         Show the currently active Go version
  goswitch list            List locally installed Go versions
  goswitch help            Show this help message

Examples:
  goswitch 1.24.13
  goswitch go1.25.12

Optional variables:
  GO_SWITCH_ROOT           Installation directory. Default: $HOME/Sviluppo
  GO_SWITCH_SYMLINK        Stable GOROOT symlink. Default: $GO_SWITCH_ROOT/go
EOF
}

_go_switch_os() {
    case "$(uname -s)" in
        Linux)  printf 'linux' ;;
        Darwin) printf 'darwin' ;;
        *)      return 1 ;;
    esac
}

_go_switch_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   printf 'amd64' ;;
        arm64|aarch64)  printf 'arm64' ;;
        armv6l)         printf 'armv6l' ;;
        *)              return 1 ;;
    esac
}

_go_switch_download() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar -o "$dest" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "$dest" "$url"
    else
        echo "Error: curl or wget is required to download Go." >&2
        return 1
    fi
}

_go_switch_sha256() {
    local file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        echo "Error: sha256sum or shasum is required to verify the download." >&2
        return 1
    fi
}

_go_switch_expected_sha() {
    local filename="$1"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is required to read the official go.dev metadata." >&2
        return 1
    fi

    python3 - "$filename" <<'PY'
import json
import sys
import urllib.request

wanted = sys.argv[1]
url = "https://go.dev/dl/?mode=json&include=all"
try:
    with urllib.request.urlopen(url, timeout=20) as response:
        releases = json.load(response)
except Exception as exc:
    print(f"Error: unable to read metadata from go.dev: {exc}", file=sys.stderr)
    sys.exit(1)

for release in releases:
    for file_info in release.get("files", []):
        if file_info.get("filename") == wanted:
            print(file_info.get("sha256", ""))
            sys.exit(0)

print(f"Error: file {wanted} was not found in the official Go metadata.", file=sys.stderr)
sys.exit(1)
PY
}

_go_switch_list() {
    local root="$1"
    local found=0

    if [ -d "$root" ]; then
        for dir in "$root"/go[0-9]*; do
            [ -d "$dir" ] || continue
            found=1
            basename "$dir"
        done
    fi

    if [ "$found" -eq 0 ]; then
        echo "No Go versions installed in $root."
    fi
}

_go_switch_current() {
    local symlink="$1"

    if [ -L "$symlink" ]; then
        echo "GOROOT symlink: $symlink -> $(readlink "$symlink")"
    else
        echo "GOROOT symlink not found: $symlink"
    fi

    if [ -x "$symlink/bin/go" ]; then
        "$symlink/bin/go" version
    elif command -v go >/dev/null 2>&1; then
        go version
    else
        echo "Go not found in PATH."
        return 1
    fi
}

_go_switch_main() {
    local root="${GO_SWITCH_ROOT:-$HOME/Sviluppo}"
    local symlink="${GO_SWITCH_SYMLINK:-$root/go}"
    local command_or_version="${1:-}"

    case "$command_or_version" in
        ""|help|-h|--help)
            _go_switch_usage
            return 0
            ;;
        list|ls)
            _go_switch_list "$root"
            return 0
            ;;
        current|version)
            _go_switch_current "$symlink"
            return $?
            ;;
    esac

    local version="${command_or_version#go}"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: invalid version: $command_or_version" >&2
        echo "Valid example: goswitch 1.24.13" >&2
        return 1
    fi

    local os arch archive_ext filename url download_path target_dir tmp_dir expected_sha actual_sha reply
    if ! os="$(_go_switch_os)"; then
        echo "Error: unsupported operating system: $(uname -s)" >&2
        return 1
    fi
    if ! arch="$(_go_switch_arch)"; then
        echo "Error: unsupported architecture: $(uname -m)" >&2
        return 1
    fi

    archive_ext="tar.gz"
    filename="go${version}.${os}-${arch}.${archive_ext}"
    url="https://go.dev/dl/${filename}"
    target_dir="$root/go${version}"
    download_path="$root/${filename}"

    if [ ! -d "$target_dir" ]; then
        echo "Go version ${version} not found in $target_dir."
        printf 'Do you want to download and install it now? (y/N) '
        IFS= read -r reply

        case "$reply" in
            y|Y|yes|YES|Yes) ;;
            *)
                echo "Installation cancelled."
                return 1
                ;;
        esac

        mkdir -p "$root"

        echo "-> Fetching official checksum for ${filename}..."
        if ! expected_sha="$(_go_switch_expected_sha "$filename")" || [ -z "$expected_sha" ]; then
            return 1
        fi

        echo "-> Download di ${url}..."
        if ! _go_switch_download "$url" "$download_path"; then
            echo "Error: download failed." >&2
            rm -f "$download_path"
            return 1
        fi

        echo "-> Verifying SHA256..."
        if ! actual_sha="$(_go_switch_sha256 "$download_path")"; then
            rm -f "$download_path"
            return 1
        fi
        if [ "$actual_sha" != "$expected_sha" ]; then
            echo "Error: invalid checksum." >&2
            echo "Expected: $expected_sha" >&2
            echo "Actual:   $actual_sha" >&2
            rm -f "$download_path"
            return 1
        fi

        tmp_dir="$(mktemp -d "$root/go${version}.tmp.XXXXXX")" || return 1
        echo "-> Extracting archive..."
        if ! tar -C "$tmp_dir" --strip-components=1 -xzf "$download_path"; then
            echo "Error: extraction failed." >&2
            rm -rf "$tmp_dir" "$download_path"
            return 1
        fi

        mv "$tmp_dir" "$target_dir"
        rm -f "$download_path"
        echo "Go ${version} installation completed."
    fi

    echo "-> Switching to Go ${version}..."
    mkdir -p "$(dirname "$symlink")"
    ln -sfn "$target_dir" "$symlink"

    echo "Switch completed successfully."
    _go_switch_current "$symlink"
}

_go_switch_main "$@"
_go_switch_finish $?
