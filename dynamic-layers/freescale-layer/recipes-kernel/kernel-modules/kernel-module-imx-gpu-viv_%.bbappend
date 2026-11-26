# NXP's galcore Kbuild embeds $(shell hostname), $(shell whoami) and $(shell date) into the
# module (HOST, GALCORE_BUILD_BY, GALCORE_BUILD_TM). Replace them with fixed values and the
# release date (SOURCE_DATE_EPOCH, exported to make).
do_configure:prepend() {
	for f in $(grep -rl -E '\$\(shell (hostname|whoami|date)\)' ${S} --include=Kbuild --include='*.config' --include=Makefile); do
		sed -i -e 's/$(shell hostname)/torizon/' -e 's/$(shell whoami)/torizon/' \
			-e 's/$(shell date)/$(shell date -u -d @$(SOURCE_DATE_EPOCH))/' $f
	done
}
