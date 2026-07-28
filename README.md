# switch-go

A small personal script to install and quickly switch between Go versions through a stable symlink.

The idea is simple:

- each Go version is installed in its own directory, for example `~/Sviluppo/go1.24.13`;
- the `~/Sviluppo/go` symlink points to the active version;
- `GOROOT` always points to the stable `~/Sviluppo/go` symlink.

This keeps your `PATH` stable. Switching Go version only requires updating the symlink.

## Files to keep in the repository

Only these files should be committed:

```text
switch-go.sh
README.md
.gitignore
```

Do not commit downloaded Go installations, for example:

```text
go
go1.24.13/
go1.25.12/
*.tar.gz
```

They are ignored by `.gitignore`.

## Requirements

The script requires:

- Bash or Zsh;
- `curl` or `wget`;
- `tar`;
- `python3`, used to read the official metadata from `go.dev`;
- `sha256sum` or `shasum`, used to verify the downloaded tarball checksum.

The script supports Linux and macOS on the most common Go architectures, such as `amd64` and `arm64`.

## Recommended installation

In my personal setup, the repository/script lives in:

```text
~/Sviluppo
```

The recommended shell configuration is the following.

### Zsh

In `~/.zshrc`:

```zsh
export GO_SWITCH_ROOT="$HOME/Sviluppo"
export GO_SWITCH_SYMLINK="$GO_SWITCH_ROOT/go"

export GOROOT="$GO_SWITCH_SYMLINK"
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

alias goswitch="source $GO_SWITCH_ROOT/switch-go.sh"
```

Then reload your shell:

```zsh
source ~/.zshrc
```

### Bash

In `~/.bashrc`:

```bash
export GO_SWITCH_ROOT="$HOME/Sviluppo"
export GO_SWITCH_SYMLINK="$GO_SWITCH_ROOT/go"

export GOROOT="$GO_SWITCH_SYMLINK"
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

alias goswitch="source $GO_SWITCH_ROOT/switch-go.sh"
```

Then reload your shell:

```bash
source ~/.bashrc
```

## Usage

Show help:

```bash
goswitch help
```

List locally installed Go versions:

```bash
goswitch list
```

Show the active version:

```bash
goswitch current
```

Install, if needed, and switch to a specific version:

```bash
goswitch 1.24.13
```

or:

```bash
goswitch go1.24.13
```

The script downloads the official tarball from `https://go.dev/dl/`, retrieves the SHA256 checksum from the official Go metadata, and verifies it before extraction.

## Default directories

By default, the script uses:

```text
GO_SWITCH_ROOT=$HOME/Sviluppo
GO_SWITCH_SYMLINK=$GO_SWITCH_ROOT/go
```

For example:

```text
~/Sviluppo/go1.24.13
~/Sviluppo/go1.25.12
~/Sviluppo/go -> ~/Sviluppo/go1.25.12
```

If you want to use another directory, change the exported variables in your shell configuration:

```bash
export GO_SWITCH_ROOT="$HOME/tools/go-versions"
export GO_SWITCH_SYMLINK="$GO_SWITCH_ROOT/go"
```

## Note about `source`

The alias uses `source`:

```bash
alias goswitch="source $GO_SWITCH_ROOT/switch-go.sh"
```

For this specific script, `source` is not strictly required because the script changes a symlink and does not need to modify the current shell environment directly. Still, keeping `source` is convenient and compatible with the historical usage of this tool.

The script can also be executed directly:

```bash
./switch-go.sh current
```

## Manual cleanup

To remove a Go version you no longer need:

```bash
rm -rf "$GO_SWITCH_ROOT/go1.24.13"
```

If that was the active version, switch to another one afterwards:

```bash
goswitch <another-version>
```
