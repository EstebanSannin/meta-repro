# jq's CVE patches rewrite both src/parser.c and src/parser.y. When the two writes land in the
# same kernel clock tick, make sees parser.y as not newer and compiles the pregenerated
# ${S}/src/parser.c; when they cross a tick (a loaded host), make copies it into ${B} first
# (0001-Support-building-with-disable-maintainer-mode...). The code is the same, but the DWARF
# file names differ and so does the GNU build-id of libjq.so. Make the grammar sources always
# older than the pregenerated C files so the copy rule never fires.
do_compile:prepend() {
	touch -h -d @1 ${S}/src/parser.y ${S}/src/lexer.l
}
