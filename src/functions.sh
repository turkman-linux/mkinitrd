#!/bin/busybox ash

function copy_binary(){
    for bin in $* ; do
        mkdir -p "$work"/lib "$work/bin"
        if command -v "$bin" | : ; then
            bin=$(which $bin)
        fi
        if ! [ -f "$bin" ] ; then
            echo "$bin not found" > /dev/stderr
            continue
        fi
        install "$bin" "$work/bin/"
        if ! ldd "$bin" 2>/dev/null | grep "=" >/dev/null; then
            continue
        fi

        LD_PRELOAD="" ldd "$bin" 2>/dev/null | grep -v "=>" | cut -d " " -f1 | tr -d "\t" | while read lib ; do
            if [ -f "$lib" ] ; then
                mkdir -p "$work"/${lib%/*}
                cp -f "$lib" "$work"/${lib%/*}
            fi
        done
        LD_PRELOAD="" ldd "$bin" | grep "=>" | cut -d " " -f3 | while read lib ; do
            if [ -f "$lib" ] ; then
                fname=${lib/*\//}
                if ! [ -f "$work/lib/$fname" ] ; then
                    install "$lib" "$work/lib/$fname"
                fi
            fi
        done
    done
    if [ -f "$work/bin/ldconfig" ] ; then
        ldconfig -r "$work"
    fi
}
alias copy_exec=copy_binary

function get_modinfo(){
    file="$1"
    suffix=${file/*./}
    rand="$RANDOM"
    if [ "$suffix" == "gz" ] ; then
        cp -f "$file" /tmp/module-"$rand".ko.gz >/dev/null
        gzip -d /tmp/module-"$rand".ko.gz  >/dev/null
        modinfo /tmp/module-"$rand".ko
        rm -f /tmp/module-"$rand".ko >/dev/null
    elif [ "$suffix" == "xz" ] ; then
        cp -f "$file" /tmp/module-"$rand".ko.xz >/dev/null
        xz -d /tmp/module-"$rand".ko.gz  >/dev/null
        modinfo /tmp/module-"$rand".ko
        rm -f /tmp/module-"$rand".ko >/dev/null
    else
        modinfo -k $kernel "$file"
    fi
}

function copy_modules(){
    for module in $@ ; do
        if ! get_modinfo "$module" >/dev/null ; then
            continue
        fi
        get_modinfo "$module" | tr -s " " | while read line; do
            name=${line/:*/}
            value=${line/*:/}
            value=${value/ /}
            if [ "$name" == "filename" ] ; then
                if ! [ -f "$value" ] ; then
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
            copy_modules "$module" &
        done
    done
    wait
}

function copy_files(){
    for arg in $@ ; do
        if [ -e $arg ] ; then
            mkdir -p "$work/"${arg%/*}
            cp -rf $arg "$work/"${arg%/*}
        fi
    done
}
