#!/bin/bash
PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJF3mRlmUdCwWujN49vBX6n1Cmp1CwEtqsYZf8eUftzt km"

cancel(){
    if [ "$1" -ne 0 ]; then
        clear
        exit 1
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    whiptail --title "Error" --msgbox "Please run this script as root." 8 40
    exit 1
fi

if [ -d /sys/firmware/efi ]; then
    BOOT_MODE=UEFI
else
    BOOT_MODE=BIOS
fi

TIMEOUT=1
if ! ping -c 1 -W $TIMEOUT google.com &> /dev/null || 
   ! ping -c 1 -W $TIMEOUT cloudflare.com &> /dev/null || 
   ! ping -c 1 -W $TIMEOUT example.com &> /dev/null || 
   ! ping -c 1 -W $TIMEOUT github.com &> /dev/null; then
    whiptail --title "Error" --msgbox "No internet connection. Please connect to the internet and run the script again." 8 60
    exit 1
fi

whiptail --title "Warning" --yesno "This script will erase all data on the selected disk. Do you want to continue?" --yes-button "Continue" --no-button "Exit" 8 60
cancel $?

dialog --title "System update" --infobox "Updating system and installing required packages" 8 50
apt-get update && apt-get install debootstrap parted -y

debian_version(){
    VERSION=$(whiptail --title "Debian version" \
        --menu "Choose a Debian release to install:" 12 40 4 \
        "bookworm" "Debian 12" \
        "trixie" "Debian 13" \
        "sid" "Debian unstable" \
        3>&1 1>&2 2>&3)
    cancel $?
}

chose_disk(){
    unset DISK_OPTIONS
    declare -a DISK_OPTIONS
    while IFS= read -r line; do
        DISK_NAME=$(echo "$line" | awk '{print $1}')
        DISK_SIZE=$(echo "$line" | awk '{print $4}')
        DISK_OPTIONS+=("$DISK_NAME" "($DISK_SIZE)")
    done < <(lsblk -n -d -p | grep disk)
    
    SELECTED_DISK=$(whiptail --title "Disk selection" \
        --menu "Select disk for Debian installation:" 15 60 5 \
        "${DISK_OPTIONS[@]}" \
        3>&1 1>&2 2>&3)
    cancel $?
}

chose_filesystem(){
    FS=$(whiptail --title "Filesystem selection" \
        --menu "Select filesystem for your partition:" 12 50 4 \
        "ext4" "Extended Filesystem 4" \
        "btrfs" "B-Tree Filesystem" \
        3>&1 1>&2 2>&3)
    cancel $?
}

create_swap(){
    if whiptail --title "Create 4GB" --yesno "Create 4GB swap partition" 8 40; then
        CREATE_SWAP_PARTITION=yes
    else
        CREATE_SWAP_PARTITION=no
    fi
}

root_password(){
    while true; do
        while true; do
            ROOT_PASSWORD=$(whiptail --title "Root password" \
                --passwordbox "Please provide your root password:" 10 70 \
                3>&1 1>&2 2>&3)
            cancel $?
            if [ -n "$ROOT_PASSWORD" ]; then
                break
            else
                whiptail --msgbox "Password can't be empty" 8 40
            fi
        done
        ROOT_PASSWORD_CONFIRM=$(whiptail --title "Confirm root password" \
            --passwordbox "Please confirm your root password:" 10 70 \
            3>&1 1>&2 2>&3)
        cancel $?
        
        if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
            break
        else
            whiptail --title "Mismatch" --msgbox "You provided two different passwords. Please enter them again" 10 70
        fi
    done   
}

create_user(){
    while true; do
        USER_LOGIN=$(whiptail --title "Login" \
            --inputbox "Please provide a username:" 8 40 \
            3>&1 1>&2 2>&3)
        cancel $?
        if [ -n "$USER_LOGIN" ]; then
            break
        else
            whiptail --msgbox "Username can't be empty" 8 40
        fi
    done
        
        USER_NAME_FULL=$(whiptail --title "Full name" \
            --inputbox "Please provide the user's full name:" 8 40 \
            3>&1 1>&2 2>&3)
        cancel $?

        while true; do
            while true; do
                USER_PASSWORD=$(whiptail --title "User password" \
                    --passwordbox "Please provide password for the new user:" 10 70 \
                    3>&1 1>&2 2>&3)
                cancel $?
                if [ -n "$USER_PASSWORD" ]; then
                    break
                else
                    whiptail --msgbox "Password can't be empty" 8 40
                fi
            done
            
            USER_PASSWORD_CONFIRM=$(whiptail --title "Confirm user password" \
                --passwordbox "Please confirm the user password:" 10 70 \
                3>&1 1>&2 2>&3)
            cancel $?
            
            if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
                break
            else
                whiptail --title "Mismatch" --msgbox "You provided two different passwords. Please enter them again" 10 70
            fi
        done   

        if whiptail --title "Sudo privileges" --yesno "Do you want to give this user sudo privileges?" 8 40; then
            USER_SUDO=yes
        else
            USER_SUDO=no
        fi
}

ssh_options(){
    if whiptail --title "SSH" --yesno "Do you want to install and enable SSH?" 8 40; then
        SSH_ENABLE=yes

        if whiptail --title "SSH root login" --yesno "Do you want to allow root login with password?" 8 40; then
            SSH_ROOT_PASSWORD=yes
        else
            SSH_ROOT_PASSWORD=no
        fi

        if whiptail --title "Public key" --yesno "Do you want to add the public key from the script?\n\n$PUBLIC_KEY" 12 80; then
            SSH_PUBLIC_KEY=yes
        else
            SSH_PUBLIC_KEY=no
        fi
    else
        SSH_ENABLE=no
    fi
}

while true; do
    while true; do
        HOSTNAME=$(whiptail --title "Hostname" --inputbox "Enter hostname for the computer:" 8 40 3>&1 1>&2 2>&3)
        cancel $?
        if [ -n "$HOSTNAME" ]; then
            break
        else
            whiptail --msgbox "Hostname can't be empty" 8 40
        fi
    done

    debian_version
    chose_disk
    chose_filesystem
    create_swap
    root_password

    if whiptail --title "New user" --yesno "Do you want to create a new user?" 8 40; then
        create_user
    fi

    ssh_options

    SUMMARY="INSTALLATION SUMMARY\n"
    SUMMARY+="Hostname: $HOSTNAME\n"
    SUMMARY+="Debian release: $VERSION\n"
    SUMMARY+="Disk: $SELECTED_DISK\n"
    SUMMARY+="Filesystem: $FS\n"
    SUMMARY+="Create SWAP: $CREATE_SWAP_PARTITION\n\n"

    if [ -n "$USER_LOGIN" ]; then
        SUMMARY+="New User Account:\n"
        SUMMARY+="  Username: $USER_LOGIN\n"
        SUMMARY+="  Full Name: $USER_NAME_FULL\n"
        SUMMARY+="  Sudo Privileges: $USER_SUDO\n\n"
    else
        SUMMARY+="New User Account: Not created\n\n"
    fi

    SUMMARY+="SSH Configuration:\n"
    SUMMARY+="  SSH Enabled: $SSH_ENABLE\n"
    if [ "$SSH_ENABLE" = "yes" ]; then
        SUMMARY+="  Root Login with Password: $SSH_ROOT_PASSWORD\n"
        SUMMARY+="  Public Key Added: $SSH_PUBLIC_KEY\n"
        if [ "$SSH_PUBLIC_KEY" = "yes" ]; then
            SUMMARY+="  Public Key: $PUBLIC_KEY\n"
        fi
    fi

    if whiptail --title "Final confirmation" \
        --yesno "$(echo -e "This is the final step. Are you sure you want to continue installation with these parameters?\n\n$SUMMARY")" 30 80; then
        break
    fi
done

whiptail --msgbox "Everything worked so far, installing and configuring system" 10 60

echo "=== CREATING PARTITIONS ==="
umount "$SELECTED_DISK" 1>/dev/null
swapoff "$SELECTED_DISK" 1>/dev/null
wipefs -af "$SELECTED_DISK"


if [ "$BOOT_MODE" == "UEFI" ]; then
    if [[ "$SELECTED_DISK" == *"nvme" ]]; then
        BOOT_PARTITION="${SELECTED_DISK}p1"
        ROOT_PARTITION="${SELECTED_DISK}p2"
    else
        BOOT_PARTITION="${SELECTED_DISK}1"
        ROOT_PARTITION="${SELECTED_DISK}2"
    fi

    echo -e 'label: gpt\nstart=1MiB,size=1GiB,type=uefi\nsize=+,type=Linux\n' | sfdisk "$SELECTED_DISK"

    mkfs.vfat "$BOOT_PARTITION" 

elif [ "$BOOT_MODE" == "BIOS" ]; then
    if [[ "$SELECTED_DISK" == *"nvme"* ]]; then
        ROOT_PARTITION="${SELECTED_DISK}p1"
    else
        ROOT_PARTITION="${SELECTED_DISK}1"
    fi

    echo -e 'label: dos\nsize=+,type=Linux,bootable\n' | sfdisk "$SELECTED_DISK"

    case $FS in
        ext4)
            mkfs.ext4 -F "$ROOT_PARTITION"
            echo "Mounting partitions..."
            mount "$ROOT_PARTITION" /mnt
            ;;
        btrfs)
            mkfs.btrfs "$ROOT_PARTITION" -f
            echo "Creating subvolumes..."
            mount "$ROOT_PARTITION" /mnt
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@var
            btrfs subvolume create /mnt/@tmp
            btrfs subvolume create /mnt/@snapshots
            echo "Mounting subvolumes..."
            mount -o noatime,compress=zstd,subvol=@ "$ROOT_PARTITION" /mnt
            mkdir -p /mnt/{home,var,tmp,.snapshots}
            mount -o noatime,compress=zstd,subvol=@home "$ROOT_PARTITION" /mnt/home
            mount -o noatime,compress=zstd,subvol=@var "$ROOT_PARTITION" /mnt/var
            mount -o noatime,compress=zstd,subvol=@tmp "$ROOT_PARTITION" /mnt/tmp
            mount -o noatime,compress=zstd,subvol=@snapshots "$ROOT_PARTITION" /mnt/.snapshots
            ;;
    esac

    debootstrap $VERSION /mnt

else
    echo "Wrong boot type"
fi

echo "=== PARTITIONS CREATED ==="

clear
