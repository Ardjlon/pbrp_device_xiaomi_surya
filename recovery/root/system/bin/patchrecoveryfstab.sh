#!/system/bin/sh
#
# Date : 2023/08/14
# Author : Ardjlon
# Credits:  OranfeFox team for wrappedkey script as reference
#

LOGF=/tmp/test.log

patchrecoveryfstab() {
    echo "Starting patchrecoveryfstab function." >>$LOGF

    rm -rf /tmp/fbe.log
    rm -rf /tmp/fbe
    vendor_temp=/tmp/fbe/vendor_temp
    vendor=/dev/block/mapper/vendor
    prop=/tmp/fbe/build.prop
    fstab=/tmp/fbe/fstab.qcom

    echo "Mounting vendor partition to $vendor_temp." >>$LOGF
    mkdir -p $vendor_temp
    mount -o rw $vendor $vendor_temp || true

    echo "Copying build.prop and fstab.qcom to temporary directory." >>$LOGF
    cp $vendor_temp/build.prop $prop
    cp $vendor_temp/etc/fstab.qcom $fstab

    echo "Unmounting vendor partition and removing temporary directory." >>$LOGF
    umount $vendor_temp
    rm -rf $vendor_temp

    [ ! -e $prop ] && {
        echo "$prop does not exist. Quitting." >>$LOGF
        return
    }

    echo "Checking for FBEv2 flags." >>$LOGF
    fstab_temp=$fstab
    fbev2=$(grep "/userdata" "$fstab_temp" | grep ":v2")
    if [ -n "$fbev2" ]; then
        echo "This ROM supports FBEv2, fixing flags." >>$LOGF
        if cp /system/etc/recovery_fbev2.fstab /system/etc/recovery.fstab; then
            echo "Flags was fixed successfully." >>$LOGF
        else
            echo "Error during fixing flags." >>$LOGF
            exit 1
        fi
    else
        echo "This ROM supports FBEv1, keeping current flags." >>$LOGF
    fi

    echo "End of patchrecoveryfstab function." >>$LOGF
}

patchrecoveryfstab

exit 0
