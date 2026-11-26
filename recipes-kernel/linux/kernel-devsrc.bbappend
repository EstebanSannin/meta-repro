# meta-torizon-bsp packs linux.tar.bz2 with a plain "tar cjf": build-time mtimes
# and filesystem order. Repack it deterministically.
do_install:append() {
    if [ -f ${D}/usr/src/linux.tar.bz2 ]; then
        t=${WORKDIR}/devsrc-repro
        rm -rf $t && mkdir -p $t
        tar --no-same-owner -xjf ${D}/usr/src/linux.tar.bz2 -C $t
        tar --sort=name --mtime=@${SOURCE_DATE_EPOCH} --owner=0 --group=0 --numeric-owner \
            --format=gnu -cjf ${D}/usr/src/linux.tar.bz2 -C $t linux
        rm -rf $t
    fi
}
