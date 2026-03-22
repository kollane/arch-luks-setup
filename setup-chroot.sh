#!/bin/bash
set -e

# Arch Linux chroot seadistamine LUKS + btrfs paigalduseks
# Kasutus: curl -sL https://raw.githubusercontent.com/kollane/arch-luks-setup/main/setup-chroot.sh | bash
# Käivita arch-chroot'is pärast pacstrap'i ja genfstab'i

# Seadistused
LUKS_PART="/dev/nvme0n1p2"
HOSTNAME="work"
USERNAME="janek"
TIMEZONE="Europe/Tallinn"

echo "=== Arch Linux chroot seadistus ==="
echo "LUKS: $LUKS_PART"
echo "Hostname: $HOSTNAME"
echo "Kasutaja: $USERNAME"
echo ""

# --- 1. Ajavöönd ---
echo "--- Ajavöönd ---"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "✓ Ajavöönd: $TIMEZONE"

# --- 2. Keel ---
echo "--- Keel ---"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "et_EE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "✓ Keel seadistatud"

# --- 3. Hostname ---
echo "--- Hostname ---"
echo "$HOSTNAME" > /etc/hostname
echo "✓ Hostname: $HOSTNAME"

# --- 4. Kasutaja ---
echo "--- Kasutaja ---"
if id "$USERNAME" &>/dev/null; then
    echo "✓ Kasutaja $USERNAME juba olemas"
else
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "✓ Kasutaja $USERNAME loodud"
fi

echo ""
echo ">>> Sisesta ROOT parool:"
passwd

echo ""
echo ">>> Sisesta $USERNAME parool:"
passwd "$USERNAME"

# sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "✓ sudo lubatud wheel grupile"

# --- 5. mkinitcpio ---
echo "--- mkinitcpio ---"
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
echo "✓ encrypt hook lisatud"
mkinitcpio -P

# --- 6. GRUB ---
echo "--- GRUB ---"
UUID=$(blkid -s UUID -o value "$LUKS_PART")
if [ -z "$UUID" ]; then
    echo "VIGA: Ei leidnud UUID-d partitsioonilt $LUKS_PART"
    echo "Käivita käsitsi: bash setup-grub-luks.sh $LUKS_PART"
    exit 1
fi

echo "LUKS UUID: $UUID"
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${UUID}:cryptroot root=/dev/mapper/cryptroot rootfstype=btrfs zswap.enabled=0\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
echo "✓ GRUB paigaldatud ja seadistatud"

# --- 7. Võrk ---
echo "--- Võrk ---"
systemctl enable NetworkManager
systemctl enable iwd

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi-backend.conf << 'EOF'
[device]
wifi.backend=iwd
EOF
echo "✓ NetworkManager + iwd lubatud"

# --- 8. SDDM ---
echo "--- SDDM ---"
pacman -S --noconfirm sddm
systemctl enable sddm
echo "✓ SDDM paigaldatud ja lubatud"

# --- Valmis ---
echo ""
echo "========================================="
echo "✓ Kõik sammud tehtud!"
echo "========================================="
echo ""
echo "Järgmised sammud:"
echo "  exit"
echo "  umount -R /mnt"
echo "  cryptsetup close cryptroot"
echo "  reboot"
echo ""
echo "Pärast rebooti jätka: luks-install.md samm 6"
