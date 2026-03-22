#!/bin/bash
set -e

# btrfs subvolume'id, monteerimine, pacstrap ja fstab
# Kasutus: bash <(curl -sL https://raw.githubusercontent.com/kollane/arch-luks-setup/master/setup-disks.sh)
# Käivita Arch ISO-s PÄRAST: cryptsetup open /dev/nvme0n1p2 cryptroot

MAPPER="/dev/mapper/cryptroot"
EFI="/dev/nvme0n1p1"
MOUNT="/mnt"
OPTS="rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2"

# Kontrolli et LUKS on avatud
if [ ! -e "$MAPPER" ]; then
    echo "VIGA: $MAPPER puudub!"
    echo "Käivita esmalt: cryptsetup open /dev/nvme0n1p2 cryptroot"
    exit 1
fi

echo "=== btrfs + pacstrap seadistus ==="

# --- 1. Subvolume'id ---
echo "--- Subvolume'id ---"
mount "$MAPPER" "$MOUNT"

for sv in @ @home @pkg @log @libvirt @snapshots; do
    if btrfs subvolume show "$MOUNT/$sv" &>/dev/null; then
        echo "  ✓ $sv juba olemas"
    else
        btrfs subvolume create "$MOUNT/$sv"
        echo "  ✓ $sv loodud"
    fi
done

umount "$MOUNT"
echo "✓ Subvolume'id loodud"

# --- 2. Monteerimine ---
echo "--- Monteerimine ---"
mount -o "$OPTS,subvol=/@" "$MAPPER" "$MOUNT"

mkdir -p "$MOUNT"/{boot,home,var/cache/pacman/pkg,var/log,var/lib/libvirt,.snapshots}

mount -o "$OPTS,subvol=/@home"      "$MAPPER" "$MOUNT/home"
mount -o "$OPTS,subvol=/@pkg"       "$MAPPER" "$MOUNT/var/cache/pacman/pkg"
mount -o "$OPTS,subvol=/@log"       "$MAPPER" "$MOUNT/var/log"
mount -o "$OPTS,subvol=/@libvirt"   "$MAPPER" "$MOUNT/var/lib/libvirt"
mount -o "$OPTS,subvol=/@snapshots" "$MAPPER" "$MOUNT/.snapshots"
mount "$EFI" "$MOUNT/boot"

echo "✓ Kõik monteeritud"
echo ""
echo "Kontroll:"
findmnt -R "$MOUNT" --output TARGET,SOURCE,FSTYPE,OPTIONS -t btrfs,vfat

# --- 3. Pacstrap ---
echo ""
echo "--- Pacstrap ---"
pacstrap -K "$MOUNT" \
    base linux linux-firmware \
    intel-ucode \
    btrfs-progs \
    grub efibootmgr grub-btrfs \
    snapper snap-pac \
    networkmanager iwd \
    sudo nano vim git

echo "✓ Baassüsteem paigaldatud"

# --- 4. fstab ---
echo "--- fstab ---"
genfstab -U "$MOUNT" >> "$MOUNT/etc/fstab"

echo "✓ fstab genereeritud"
echo ""
echo "fstab sisu:"
grep -v "^#" "$MOUNT/etc/fstab" | grep -v "^$"

echo ""
echo "========================================="
echo "✓ Kettad, pacstrap ja fstab valmis!"
echo "========================================="
echo ""
echo "Järgmised sammud:"
echo "  arch-chroot /mnt"
echo "  bash <(curl -sL https://raw.githubusercontent.com/kollane/arch-luks-setup/master/setup-chroot.sh)"
