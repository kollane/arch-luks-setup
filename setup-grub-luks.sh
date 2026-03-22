#!/bin/bash
set -e

# GRUB seadistamine LUKS-iga bootimiseks
# Kasutus: bash setup-grub-luks.sh /dev/nvme0n1p2
# Käivita chroot'is pärast pacstrap'i

LUKS_PART="${1:?Kasutus: bash setup-grub-luks.sh /dev/nvme0n1p2}"
GRUB_CONF="/etc/default/grub"

# Leia UUID
UUID=$(blkid -s UUID -o value "$LUKS_PART")
if [ -z "$UUID" ]; then
    echo "VIGA: Ei leidnud UUID-d partitsioonilt $LUKS_PART"
    exit 1
fi

echo "LUKS partitsioon: $LUKS_PART"
echo "UUID: $UUID"

# Kirjuta GRUB config
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${UUID}:cryptroot root=/dev/mapper/cryptroot rootfstype=btrfs zswap.enabled=0\"|" "$GRUB_CONF"

echo ""
echo "Kontroll:"
grep GRUB_CMDLINE_LINUX "$GRUB_CONF"

# Paigalda GRUB
echo ""
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo "✓ GRUB seadistatud LUKS bootimiseks"
