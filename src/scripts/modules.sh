if [ -f /etc/modules ] ; then
    cat /etc/modules | while read module ; do
        modprobe $module || true
    done
fi