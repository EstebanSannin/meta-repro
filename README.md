# meta-repro

Experimental Yocto layer that makes Torizon OS 8 (`wrynose`) release builds
**byte-identical**: two independent builds of the same inputs produce the same
images, packages and OSTree commit, bit for bit.

Tested on `verdin-imx8mp` and `intel-corei7-64` (`torizon-docker`): four clean
builds on two different hosts gave identical Tezi images, OTA tarballs, wic
images, OSTree commits and every ipk/rpm.

## Cache or no cache: it doesn't matter

The output of a reproducible build does not depend on how it was produced. A
build that reuses an sstate cache and a download directory gives the same bytes
as a build from scratch, so the cache does not need to be trusted.

This is what makes in-toto attestation practical: instead of forcing every
release build to run without cache, a second party (or a second machine) rebuilds
the same inputs and signs its own link. If the products match, a threshold-2
layout verifies. Any tampering in a cache shows up as a hash mismatch.

## How to run a reproducible build

1. Check out a **pinned** manifest (a release tag, not a moving branch) with
   `repo init` / `repo sync`. Every layer must be at the same commit on every
   builder: the layer commit IDs end up in `/usr/etc/buildinfo` inside the image.
2. Set up the build environment as usual, then **remove `use-head-next`** from
   `build/conf/auto.conf` (the tdx `setup-environment` adds it, and it pulls
   moving `AUTOREV` sources).
3. Add this layer (`bitbake-layers add-layer .../meta-repro`) and add this
   line to `build/conf/local.conf`:

   ```
   require conf/repro-release.conf
   ```

   [`conf/repro-release.conf`](conf/repro-release.conf) sets the release
   identity (`TDX_PURPOSE = "Release"`), a fixed `DATETIME`, the image class,
   the SDE guard, the x86 wks file and a fixed x86 rootfs size, and drops the
   `.vdi`/`.vmdk` images. Set `DATETIME` (and, if needed, the rootfs size) once
   per release.

4. x86 only: apply
   [`patches/meta-updater-wic-no-oe-path.patch`](patches/meta-updater-wic-no-oe-path.patch)
   to meta-updater (`git -C layers/meta-updater apply ...`). It is a build fix,
   not a reproducibility fix: wic runs outside BitBake and can't import `oe.path`.

5. Fetch everything first, then build:

   ```
   bitbake --runall=fetch torizon-docker
   bitbake torizon-docker
   ```

6. Compare `deploy/` between builders (for example `sha256sum` over all
   files, ignoring `*.testdata.json`), or record and verify in-toto links.

## Rules for release builds

- **Start from an empty OSTree repo** (`deploy/images/<machine>/ostree_repo`),
  otherwise the commit gets a parent and differs.
- **Use only caches from complete builds.** Never reuse a download directory or
  sstate written by a build that was killed: an interrupted `git clone` leaves a
  broken mirror that BitBake reuses.
- **Stop builds with SIGTERM, never SIGKILL.**
- **Don't fetch from two builds into one download directory at the same time.**
  Run `--runall=fetch` for one build at a time.
- **Keep `repro-sde-guard` enabled.** Without it, `rm_work` can delete a
  recipe's `SOURCE_DATE_EPOCH` file and a later packaging rerun silently uses the
  2011 fallback date.
- After changing only a layer commit, force the initramfs to rebuild: it embeds
  buildinfo too.

## What the layer changes

| File | Fixes |
|---|---|
| `classes/repro-sde-guard.bbclass` | Stops the build if a recipe that unpacks sources lost its `SOURCE_DATE_EPOCH` file |
| `classes/repro-image.bbclass` | Fixed ext4 UUID and hash seed, sorted and clamped tar archives, root-owned Tezi tarball, stable sizes in `image.json` |
| `files/wic/efiimage-sota-repro.wks` | Fixed GPT and ESP identifiers (x86) |
| `recipes-extended/ostree/` | OSTree summary time follows `SOURCE_DATE_EPOCH` |
| `classes/cyclonedx-export.bbclass` | Deterministic CycloneDX SBOMs (stable UUIDs, timestamps, order) |
| `recipes-devtools/jq/` | Avoids a timestamp race that regenerated the parser |
| `recipes-devtools/lshw/` | `gzip -n`, always rebuilds the shipped translation |
| `recipes-kernel/linux/kernel-devsrc.bbappend` | Deterministic `linux.tar.bz2` |
| `dynamic-layers/freescale-layer/` | Removes build host, user and date from the GPU driver |

Most of these belong upstream (oe-core, meta-oe, meta-freescale, meta-updater,
meta-cyclonedx, meta-torizon); this layer is the place to prove them first.

## Known limits

- SPDX 3.0 SBOMs match in content but not in bytes: they embed task hashes that
  depend on each builder's hash-equivalence database. Starting from an empty
  hash-equivalence database should make them byte-identical too (not tested).
- `*.testdata.json` contains build paths and is excluded from comparisons.
