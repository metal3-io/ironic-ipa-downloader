# Ironic IPA Downloader - AI Agent Instructions

Instructions for AI coding agents. For project overview, see [README.md](README.md).

## Overview

Simple init container that downloads Ironic Python Agent (IPA) kernel and
initramfs images to a shared volume. Used by
[Ironic Standalone Operator](https://github.com/metal3-io/ironic-standalone-operator)
as an init container before Ironic starts.

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Container image (CentOS Stream base + curl) |
| `get-resource.sh` | Download script with caching and ETag support |

## Testing Standards

CI uses GitHub Actions (`.github/workflows/`). Run locally before PRs:

| Command | Purpose |
|---------|---------|
| `./hack/shellcheck.sh` | Shell script linting |
| `./hack/markdownlint.sh` | Markdown linting |

Build with: `podman build -t ironic-ipa-downloader .`

## Code Conventions

- **Shell**: Use `set -eux` in scripts

## Environment Variables

Key configuration (see `README.md` for full list):

- `IPA_BASEURI` - Base URL for IPA images
- `IPA_BRANCH` - OpenStack branch (default: `master`)
- `IPA_FLAVOR` - OS flavor (default: `centos9`)
- `IPA_ARCH` - Architecture suffix for multi-arch support
- `SHARED_DIR` - Output directory (default: `/shared`)

## Code Review Guidelines

When reviewing pull requests:

1. **Security** - No hardcoded credentials, validate URLs
1. **Consistency** - Match existing shell patterns in `get-resource.sh`
1. **Breaking changes** - Flag environment variable changes

## AI Agent Guidelines

1. Read `README.md` for environment variables
1. Make minimal edits to `get-resource.sh`
1. Run `./hack/shellcheck.sh` before committing
1. Test download logic with `podman run`

## Integration

Downloads IPA images to `/shared/html/images/` as symlinks:

- `ironic-python-agent.kernel`
- `ironic-python-agent.initramfs`

When `IPA_ARCH` is set, filenames include the architecture suffix (e.g.,
`ironic-python-agent-aarch64.kernel`).

These are served by ironic-image's httpd for PXE boot.

## Related Documentation

- [Ironic Image](https://github.com/metal3-io/ironic-image)
- [Metal3 Book](https://book.metal3.io/ironic/ironic-container-images)
