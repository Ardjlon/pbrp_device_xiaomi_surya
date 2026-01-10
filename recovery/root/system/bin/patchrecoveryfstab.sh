#!/system/bin/sh
#
# Date : 2026/01/09
# Author : Ardjlon
# Credits:  OrangeFox team for wrappedkey script as reference
#

DYNAMIC_FBE_DIR="/tmp/dynamic_fbe"
LOGF="$DYNAMIC_FBE_DIR/patchrecoveryfstab.log"

# Clean and create directory
rm -rf "$DYNAMIC_FBE_DIR" 2>/dev/null
mkdir -p "$DYNAMIC_FBE_DIR"

# Start log
echo "=== patchrecoveryfstab.sh - Start: $(date) ===" > "$LOGF"
echo "Working directory: $DYNAMIC_FBE_DIR" >> "$LOGF"

echo "Starting patchrecoveryfstab..." >> "$LOGF"

# Create temp directory to mount vendor
vendor_temp_dir="$DYNAMIC_FBE_DIR/vendor_temp"
mkdir -p "$vendor_temp_dir"

# Mount ROM's vendor partition
vendor_device="/dev/block/mapper/vendor"
echo "Mounting vendor from: $vendor_device" >> "$LOGF"

# Try mapper first
if ! mount -o rw "$vendor_device" "$vendor_temp_dir" 2>/dev/null; then
    echo "Mapper failed, trying by-name..." >> "$LOGF"
    vendor_device="/dev/block/bootdevice/by-name/vendor"

    # Try by-name
    if [ -b "$vendor_device" ] && mount -o rw "$vendor_device" "$vendor_temp_dir" 2>/dev/null; then
        echo "Vendor mounted via by-name" >> "$LOGF"
    else
        echo "ERROR: Could not mount vendor" >> "$LOGF"
        rm -rf "$DYNAMIC_FBE_DIR"
        exit 1
    fi
else
    echo "Vendor mounted via mapper" >> "$LOGF"
fi

# Copy fstab.qcom from ROM
rom_fstab="$DYNAMIC_FBE_DIR/fstab.qcom"
if [ -f "$vendor_temp_dir/etc/fstab.qcom" ]; then
    cp "$vendor_temp_dir/etc/fstab.qcom" "$rom_fstab"
    echo "fstab.qcom copied from ROM" >> "$LOGF"
else
    echo "ERROR: fstab.qcom not found in vendor/etc/" >> "$LOGF"
    umount "$vendor_temp_dir" 2>/dev/null
    rm -rf "$DYNAMIC_FBE_DIR"
    exit 1
fi

# Unmount vendor
umount "$vendor_temp_dir" 2>/dev/null
rm -rf "$vendor_temp_dir"

# Determine FBE type
echo "Analyzing ROM's fstab.qcom..." >> "$LOGF"
if grep -q "/userdata.*:v2" "$rom_fstab" 2>/dev/null; then
    echo "FBEv2 detected in ROM" >> "$LOGF"

    # Apply FBEv2 to recovery
    if [ -f "/system/etc/recovery_fbev2.fstab" ]; then
        cp "/system/etc/recovery_fbev2.fstab" "/system/etc/recovery.fstab"
        echo "recovery.fstab updated to FBEv2" >> "$LOGF"
    fi

    # Set FBEv2 properties
    resetprop ro.crypto.allow_encrypt_override true
    resetprop ro.crypto.dm_default_key.options_format.version 2
    resetprop ro.crypto.volume.options ::v2
    resetprop ro.crypto.volume.filenames_mode aes-256-cts
    resetprop ro.crypto.volume.metadata.method dm-default-key
    resetprop ro.hardware.keystore_desede true
    echo "FBEv2 properties set" >> "$LOGF"

else
    echo "FBEv1 detected in ROM" >> "$LOGF"

    # Apply FBEv1 to recovery
    if [ -f "/system/etc/recovery_fbe.fstab" ]; then
        cp "/system/etc/recovery_fbe.fstab" "/system/etc/recovery.fstab"
        echo "recovery.fstab updated to FBEv1" >> "$LOGF"
    fi

    # Set FBEv1 properties (delete FBEv2, set FBEv1)
    resetprop --delete ro.crypto.allow_encrypt_override 2>/dev/null
    resetprop --delete ro.hardware.keystore_desede 2>/dev/null
    resetprop --delete ro.crypto.volume.metadata.method 2>/dev/null
    resetprop --delete ro.crypto.volume.filenames_mode 2>/dev/null
    resetprop --delete ro.crypto.volume.options 2>/dev/null
    resetprop --delete ro.crypto.dm_default_key.options_format.version 2>/dev/null
    resetprop --delete persist.sys.fuse.passthrough.enable 2>/dev/null

    resetprop fbe.metadata.wrappedkey true
    echo "FBEv1 property set: fbe.metadata.wrappedkey=true" >> "$LOGF"
fi

echo "=== patchrecoveryfstab.sh - End: $(date) ===" >> "$LOGF"

exit 0
