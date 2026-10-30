# Ironic IPA Downloader

Container image that downloads the Ironic Python Agent (IPA) kernel and
initramfs into a shared volume, where ironic-image's httpd serves them
for network boot. Ironic Standalone Operator and BMO's
`ironic-deployment` run it as an init container.
Project overview: [README.md](README.md). Contribution rules:
[Metal3 community guide](https://github.com/metal3-io/community/blob/main/CONTRIBUTING.md).

This file holds only what you cannot cheaply infer from the code. Where it
disagrees with the code, trust the code and report the mismatch.

## AI-assisted contributions

Metal3 follows the CNCF and
[Linux Foundation generative AI policy](https://www.linuxfoundation.org/legal/generative-ai).

- AI is a tool. The human who opens a PR is its author and is responsible
  for every line of it, including licensing and third-party content.
- Review is a conversation between humans. A PR where an agent or bot
  answers reviewers will be closed. Agents may draft changes; the
  contributor reads them, understands them, and replies personally.

- Keep changes surgical. The smallest complete change that solves the
  stated problem wins. Every added file, function, flag, dependency or
  test helper must trace to that problem; anything that does not is
  bloat and gets removed. Prefer reusing existing code over new code.
  Report unrelated findings instead of fixing them in the same PR.

## Repository map

Two files do the work: `Dockerfile` (CentOS Stream base, the script as
entrypoint) and `get-resource.sh`. All configuration comes from
environment variables read at the top of `get-resource.sh`; the README
documents the user-facing ones.

## Testing

- No Makefile. Checks live in `hack/`; they run in a container and
  honor `CONTAINER_RUNTIME` (default `podman`). YAML lint runs only in
  GitHub Actions. CI jobs:
  [Prow](https://github.com/metal3-io/project-infra/blob/main/prow/config/jobs/metal3-io/ironic-ipa-downloader.yaml)
  and `.github/workflows/`.
- Conventions are whatever the existing script and lint configs do.
- Before finishing, run the `hack/` checks. For a `get-resource.sh`
  change, build the image and run it twice against a scratch directory
  mounted at `/shared`: the second run takes the ETag reuse path. Each
  run downloads about 400 MB from the default `IPA_BASEURI`.

## Invariants

These apply to writing and to reviewing changes.

- **Output contract.** Consumers depend on the layout under
  `${SHARED_DIR}/html/images/`: symlinks `ironic-python-agent.kernel`,
  `.initramfs` and `.headers`, with `_${IPA_ARCH}` appended to the base
  name when `IPA_ARCH` is set (for example
  `ironic-python-agent_aarch64.kernel`). They also depend on the env var
  names, which Ironic Standalone Operator sets in
  `pkg/ironic/containers.go`. Renaming either breaks deployments; mark
  it breaking.
- **Restart safety.** The script runs on every pod start against a
  volume that may persist. It must stay idempotent: download into a temp
  dir under `${SHARED_DIR}/tmp`, move the result into place, and then
  switch the symlinks.
- **Security.** Never weaken security to make something work. TLS
  verification stays on unless the user opts in with `CURL_INSECURE`.
  Keep the `sha256sum --check` against the published `.sha256`. Treat
  the downloaded archive, the checksum file and the response headers as
  untrusted: the ETag becomes part of a directory name. Call out any
  change to TLS, proxy or checksum handling in the PR description.
- **Pinning.** Pin new external references: GitHub Actions by commit SHA,
  container images by digest, downloaded binaries by checksum.

## External references

- [Metal3 Book, Ironic container images](https://book.metal3.io/ironic/ironic-container-images)
- [ironic-image](https://github.com/metal3-io/ironic-image), which serves the images
- [Ironic Standalone Operator][irso], the main consumer

[irso]: https://github.com/metal3-io/ironic-standalone-operator
