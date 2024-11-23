#!/bin/sh

function copy_binary(){
    set +e
    for bin in $@ ; do
        mkdir -p "$work"/lib "$work/bin"
        if command -v "$bin" | : ; then
            bin=$(which $bin)
        fi
        if ! [ -f "$bin" ] ; then
            echo "$bin not found" > /dev/stderr
            return 1
        fi
        cp "$bin" "$work/bin/"
        LD_PRELOAD="" ldd "$bin" | grep -v "=>" | cut -d " " -f1 | tr -d "\t" | while read lib ; do
            if [ -f "$lib" ] ; then
                mkdir -p "$work"/${lib%/*}
                cp -f "$lib" "$work"/${lib%/*}
            fi
        done
        LD_PRELOAD="" ldd "$bin" | grep "=>" | cut -d " " -f3 | while read lib ; do
            if [ -f "$lib" ] ; then
                fname=${lib/*\//}
                if ! [ -f "$work/lib/$fname" ] ; then
                    cp -f "$lib" "$work/lib/$fname"
                fi
            fi
        done
    done
    if [ -f "$work/bin/ldconfig" ] ; then
        unshare -ru chroot "$work" /bin/ldconfig
    fi
    set -e
}
alias copy_exec=copy_binary

function copy_modules(){
    for module in $@ ; do
        $(which modinfo) -k $kernel "$module" | tr -s " "| while read line; do
            name=${line/:*/}
            value=${line/*:/}
            value=${value/ /}
            if [ "$name" == "filename" ] ; then
                if ! [ -f "$$value" ] ; then
                    continue
                fi
                if [ -f "$work/"$value ] ; then
                    continue
                fi
                mkdir -p "$work/"${value%/*}
                cp -f $value "$work/"$value
            elif [ "$name" == "depends" ] ; then
                for dep in ${value//,/ } ; do
                    copy_modules $dep
                done
            elif [ "$name" == "firmware" ] && [ "$firmware" == "1" ]; then
                if [ -f /lib/firmware/$value ] ; then
                    mkdir -p "$work/"/lib/firmware/${value%/*}
                    cp -f /lib/firmware/$value "$work/lib/firmware/"$value
                fi
            fi
        done
    done
}
alias manual_add_modules=copy_modules

function copy_module_tree() {
    for arg in "$@"; do
        if ! [ -d /lib/modules/$kernel/$arg/ ] ; then
            continue
        fi
        find  /lib/modules/$kernel/$arg -type f | while read module ; do
            copy_modules "$module"
        done
    done
}

function copy_files(){
    for arg in $@ ; do
        if [ -e $arg ] ; then
            mkdir -p "$work/"${arg%/*}
            cp -rf $arg "$work/"${arg%/*}
        fi
    done
}