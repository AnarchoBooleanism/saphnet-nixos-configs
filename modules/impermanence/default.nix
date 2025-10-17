# Configuration for using Impermanence, for keeping your system clean between reboots.
# This configuration assumes you are using BTRFS, like with modules/disko/impermancence-btrfs.nix.
# If using sops-nix, make sure to use modules/sops-nix/default-impermanence.nix.
{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  # This is a basic list of directories/files that will be hosted in /persist.
  # If you want to add any of your own for your machine's configuration, make sure that
  # your configuration.nix file contains environment.persistence."/persist", with
  # subvalues for directories and files.
  # Examples of directories/files you might want to add:
  # - /var/lib/docker - If you have Docker
  # - /etc/komodo - For the Komodo control server
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';

  fileSystems."/persist".neededForBoot = true;
}