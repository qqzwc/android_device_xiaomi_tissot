#!/sbin/sh
### flash_image script

# only source it, we set our own OUT_FD
source /tissot_manager/tools.sh

OUT_FD=/proc/$$/fd/$2

abort() {
	ui_print
	ui_print "[!] Error: $1"
	ui_print
	exit 1
}


sourceFile=`cat /tmp/flash_image_source`
targetMount=`cat /tmp/flash_image_target | sed 's|;||'`

# verify source
if [ ! -f "$sourceFile" ]; then
	abort "Source file not found"
fi

ui_print
ui_print "[#] Starting flash from $sourceFile"

targetBlock=
targetType=
isFilesystem=false


# look for mount point and type from recovery.fstab
while read LINE; do
	firstChar=`echo "$LINE" | head -c 1`
	if [ "$firstChar" = "#" -o "$firstChar" = "" ]; then 
		# skip comments and blank lines
		continue
	fi
    entryMountPoint=$(echo "$LINE" | awk '{ print $2 }')
	if [ "$entryMountPoint" = "$targetMount" ]; then
		targetBlock=$(echo "$LINE" | awk '{ print $1 }')
		targetType=$(echo "$LINE" | awk '{ print $3 }')
		ui_print "    [i] Target = $targetBlock [$targetType]"
		break;
	fi
done < /etc/recovery.fstab

if [ "$targetBlock" = "" -o "$targetType" = "" ]; then
	# wasn't found in fstab - look for mount point and type from twrp.flags
	while read LINE; do
		firstChar=`echo "$LINE" | head -c 1`
		if [ "$firstChar" = "#" -o "$firstChar" = "" ]; then 
			# skip comments and blank lines
			continue
		fi
		entryMountPoint=$(echo "$LINE" | awk '{ print $1 }')
		if [ "$entryMountPoint" = "$targetMount" ]; then
			targetBlock=$(echo "$LINE" | awk '{ print $3 }')
			targetType=$(echo "$LINE" | awk '{ print $2 }')
			ui_print "    [i] Target = $targetBlock [$targetType]"
			break;
		fi
	done < /etc/twrp.flags
fi

if [ "$targetBlock" = "" -o "$targetType" = "" ]; then
	abort "Could not find flash target"
fi

# look for sparse image magic
sparse_magic=`hexdump -e '"%02x"' -n 4 "$sourceFile"`

if [ "$sparse_magic" = "ed26ff3a" ]; then
	ui_print "    [i] Detected sparse image"
	ui_print "    [#] Flashing via simg2img..."
	simg2img $sourceFile $targetBlock
	result=$?
else
	ui_print "    [i] Sparse magic not found, assuming raw image"
	ui_print "    [#] Flashing via dd..."
	dd if=$sourceFile of=$targetBlock
	result=$?
fi

# cleanup
rm /tmp/flash_image_source
rm /tmp/flash_image_target

exit $result