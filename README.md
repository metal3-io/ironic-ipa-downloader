# ironic-ipa-downloader

This repository contains scripts to download the Ironic-Python-Agent (IPA)
ramdisk images to a shared volume. By default, we pull IPA images from
[Ironic upstream](https://tarballs.opendev.org/openstack/ironic-python-agent/dib)
archive where an image is built on every commit to the *master* git branch.

## How to set env variables for use

To use a stable branch, export the `IPA_BRANCH` variable when downloading
from the default URI.

You can override the default URI with a custom one by exporting the `IPA_BASEURI`
environment variable.

If the archive follows different naming conventions than the default, you can
override the file names by specifying the `IPA_FILENAME` variable.

You can specify the IPA image architecture by exporting the `IPA_ARCH` environment
variable. Doing so will save the image as an architecture specific image.

To have multiple images available for different architectures you should run
this container multiple times as multiple initContainers with different
configuration and set the `IPA_ARCH` variable to a different value each time, you
will also need to set the `IPA_BASEURI` and `IPA_FLAVOR` to point to archives for
the correct architecture as default URIs are for x86_64 only.

## How to build custom IPA ramdisk image

To build custom IPA ramdisk image, follow the steps below. For more information
check the disk-image builder
[document](https://docs.openstack.org/diskimage-builder/latest/developer/index.html#quickstart).

1. Create a virtual environment

   ```shell
   virtualenv myenv
   source myenv/bin/activate
   ```

1. Install
   [Ironic Python Agent Builder](https://github.com/openstack/ironic-python-agent-builder).
   Ironic community provides handy utility `ironic-python-agent-builder` to
   quickly build ramdisk images, which is using
   [disk-builder](https://docs.openstack.org/diskimage-builder/latest/developer/index.html#quickstart)
   under the hood.

   ```shell
   pip3 install ironic-python-agent-builder
   ```

1. Build the IPA initramfs and kernel.

   ```shell
   ironic-python-agent-builder --output ironic-python-agent \
     --release 9-stream centos \
     --element='dynamic-login'
   ```

   - `--release` - Distribution release to use.
   - `--element` - Additional Disk Image Builder(DIB) element to use. List of
     available [elements](https://docs.openstack.org/diskimage-builder/latest/).
   - `output` - Output base file name
   - `centos` - Base distribution.
   - [dynamic-login](https://docs.openstack.org/diskimage-builder/latest/elements/dynamic-login/README.html)
     DIB element allows to inject SSH key in the image.

At the end of the process you will have

- `ironic-python-agent.initramfs` - deploy ramdisk.
- `ironic-python-agent.kernel` - a binary file containing the kernel.
