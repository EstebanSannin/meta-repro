# ostree.summary.last-modified uses the wall clock; take SOURCE_DATE_EPOCH instead.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-repo-honour-SOURCE_DATE_EPOCH-for-summary-last-modified.patch"
