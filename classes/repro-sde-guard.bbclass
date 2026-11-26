# SOURCE_DATE_EPOCH guard (global class: INHERIT += "repro-sde-guard").
#
# oe-core reads SOURCE_DATE_EPOCH from ${SDE_FILE} (${WORKDIR}/source-date-epoch/...), written by
# do_unpack or restored by do_deploy_source_date_epoch_setscene. If the file is missing, it falls
# back to SOURCE_DATE_EPOCH_FALLBACK (2011-04-05) with only a debug message.
#
# rm_work deletes ${WORKDIR}. do_package_write_* has deptask/rdeptask on do_packagedata, so it
# reruns when a dependency changes even though do_package is "current"; it then packs with the
# fallback date. The value is not in the task hash, so that output goes into sstate under the
# normal signature and is served again later (seen with aktualizr-torizon on verdin-imx8mp).
#
# 1. Keep the SDE file when rm_work cleans up.
RM_WORK_EXCLUDE_ITEMS += "source-date-epoch"

# 2. Never package with a silent fallback: fail if the file is missing.
#    Recipes without a do_unpack task (packagegroups, deltask do_unpack) never get the file:
#    for them the fallback is the designed, deterministic value, so they are not checked.
python repro_require_sde_file () {
    if 'do_unpack' not in (d.getVar('__BBTASKS', False) or []) or d.getVarFlag('do_unpack', 'noexec'):
        return
    sde = d.getVar('SDE_FILE')
    if not os.path.exists(sde):
        bb.fatal("repro: %s is missing, SOURCE_DATE_EPOCH would fall back to %s. "
                 "Rerun do_unpack (bitbake -C unpack %s) or build without rm_work."
                 % (sde, d.getVar('SOURCE_DATE_EPOCH_FALLBACK'), d.getVar('PN')))
}
do_package[prefuncs] += "repro_require_sde_file"
do_package_write_ipk[prefuncs] += "repro_require_sde_file"
do_package_write_rpm[prefuncs] += "repro_require_sde_file"
do_package_write_deb[prefuncs] += "repro_require_sde_file"
