# Make the Torizon OTA image filesystems reproducible.
# Inherit through IMAGE_CLASSES, so only image recipes change.

# Fixed IDs for the release. They must be valid UUIDs; derive them from the
# release tag (e.g. uuid5) so every release has its own.
REPRO_ROOTFS_UUID ?= "6b1f5a52-1c1e-5d4e-9a6b-7d2c0f3e8a11"
REPRO_ROOTFS_HASH_SEED ?= "${REPRO_ROOTFS_UUID}"

# ota-ext4: fixed UUID and directory hash seed, fixed inode times
EXTRA_IMAGECMD:ota-ext4:append = " -U ${REPRO_ROOTFS_UUID} -E hash_seed=${REPRO_ROOTFS_HASH_SEED}"
export E2FSPROGS_FAKE_TIME = "${REPRODUCIBLE_TIMESTAMP_ROOTFS}"
# the fsck that runs after mkfs stamps "last write/checked" with its own clock
export E2FSCK_TIME = "${REPRODUCIBLE_TIMESTAMP_ROOTFS}"

# The ostree deploy (do_image_ota) creates dirs and files with wall-clock mtimes
# in OTA_SYSROOT / OTA_BOOT; clamp them before ext4/ESP creation.
repro_clamp_ota_mtimes () {
    for d in ${OTA_SYSROOT} ${OTA_BOOT}; do
        [ -d "$d" ] && find "$d" -print0 | xargs -0 touch -h --date=@${REPRODUCIBLE_TIMESTAMP_ROOTFS}
    done
    true
}
do_image_ota[postfuncs] += "repro_clamp_ota_mtimes"

# NSS .chk files are re-signed by shlibsign in the rootfs postinst with a random
# HMAC key. They are only checked in FIPS mode; ship them empty as the nss
# package does (the recipe notes they can be regenerated on target).
repro_empty_nss_chk () {
    for f in ${IMAGE_ROOTFS}${libdir}/libsoftokn3.chk ${IMAGE_ROOTFS}${libdir}/libfreebl3.chk ${IMAGE_ROOTFS}${libdir}/libnssdbm3.chk; do
        [ -f "$f" ] && : > "$f"
    done
    true
}
ROOTFS_POSTPROCESS_COMMAND += "repro_empty_nss_chk;"

# Tar-based images (Arm: the Tezi rootfs <image>.ota.tar.zst and the outer Tezi tarball).
# The ota tar conversion runs inside do_image_ota, before the mtime clamp above, and the
# Torizon/Toradex tar commands neither sort entries nor clamp mtimes: the hard-link
# "first copy" and 7000+ wall-clock mtimes changed between builds. :append because
# meta-updater hard-sets IMAGE_CMD_TAR.
# --xattrs (meta-updater) makes GNU tar write pax headers, which carry atime and ctime: drop them.
IMAGE_CMD_TAR:append = " --sort=name --mtime=@${REPRODUCIBLE_TIMESTAMP_ROOTFS} --clamp-mtime --pax-option=delete=atime,delete=ctime"

# image_type_tezi records the uncompressed rootfs size for image.json with `du -ks` on the
# tar, which depends on the host filesystem's block allocation. Use the apparent size.
python () {
    for v in ('CONVERSION_CMD:tar', 'IMAGE_CMD:tar'):
        val = d.getVar(v, False)
        if val and 'du -ks ' in val:
            d.delVarFlag(v, '_append')
            d.setVar(v, val.replace('du -ks ', 'du -ks --apparent-size '))
}

# The outer Tezi tarball stores the uid/gid of the deploy files (the build user). Repack it with
# root:root, same member order and the same tar options.
repro_tezi_owner () {
    f=$(readlink -f "${IMGDEPLOYDIR}/${TEZI_IMAGE_NAME}-Tezi.tar")
    [ -f "$f" ] || { bbwarn "repro: no Tezi tarball to repack"; return 0; }
    t=$(mktemp -d "${WORKDIR}/tezi-repack.XXXXXX")
    tar -tf "$f" > "$t.list"
    # not root here: do not try to restore the owners (set to 0:0 when repacking)
    tar -C "$t" --no-same-owner -xpf "$f"
    ${IMAGE_CMD_TAR} --owner=0 --group=0 --numeric-owner --no-recursion -C "$t" -cf "$f.repro" -T "$t.list"
    mv "$f.repro" "$f"
    rm -rf "$t" "$t.list"
}
do_image_teziimg[postfuncs] += "repro_tezi_owner"
