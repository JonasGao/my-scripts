#!/bin/bash
[ -z "$1" ] && echo "Please provide DEV" && exit 1
[ -z "$2" ] && echo "Please provide MTN" && exit 2
DEV=$1
MNT=$2
PAR="${DEV}1"
printf """Partition~
Will:
  Init disk:        \"$DEV\"
  Create partition: \"$PAR\"
  Mount it to:      \"$MNT\"
  Format:           \"ext4\"
"""
read -p "Continue? " -n 1 -r
echo
if [ "$REPLY" != "y" ]
then
  echo "Abort~"
  exit 0
fi
echo "Partition..."
(
echo n # Add a new partition
echo p # Primary partition
echo 1 # Partition number
echo   # First sector (Accept default: 1)
echo   # Last sector (Accept default: varies)
echo w # Write changes
) | fdisk "$DEV"
echo "Formating..."
mkfs.ext4 "$PAR"
echo "Mounting..."
mkdir -p "$MNT"
mount "$PAR" "$MNT"
echo "Finish"