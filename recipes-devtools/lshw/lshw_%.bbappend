# lshw's Makefile gzips the ID databases without -n, so the gzip header carries
# the build time. Recompress without name/timestamp.
do_install:append() {
    for f in ${D}${datadir}/lshw/*.gz; do
        [ -f "$f" ] || continue
        gunzip -f "$f"
        gzip -9n "${f%.gz}"
    done
}

# lshw's git tree ships a prebuilt src/po/fr.mo next to fr.po. make rebuilds it only when the
# checkout left fr.po newer than fr.mo (a timestamp race), and msgfmt's output differs from the
# shipped file. Always build it from fr.po.
do_compile:prepend() {
	rm -f ${S}/src/po/fr.mo
}
