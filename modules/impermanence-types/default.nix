# Configuration for using Impermanence, for keeping your system clean between reboots.
# This configuration assumes you are using BTRFS, like with modules/disko-types/impermanence-btrfs.nix.
# If using sops-nix, make sure to use modules/sops-nix-types/default-impermanence.nix.
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

  boot.initrd.systemd.services."impermanence-root-rollback" = {
    description = "Rollback root subvolume to empty state, keeping archives from past 30 days";

    wantedBy = [ "initrd-root-device.target" ];
    after = [ "initrd-root-device.target" ];
    before = [ "sysroot.mount" ];

    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";

    # !!! IMPORTANT NOTE !!! (Save yourself from more hours of agony...)
    # For scripts in early-stage services like this (running in initrd), any binary you run, especially
    # "mount", MUST be referred to with their full path, in /bin.
    # Otherwise, running commands, like "mount", WILL result in a "command not found" error, with the
    # service failing before it can do anything.
    # Filling in the "path" attribute, used for systemd services, with Nix package names, will not do
    # anything at all, and neither using systemd.initrd.systemd.storePaths, nor directly referring to
    # the binaries within the Nix store (e.g. "${pkgs.util-linux}/bin/mount") will get the service to
    # run the necessary binary.
    # Also, before you ask, all of the packages needed for this job are already included with the
    # initrd environment of NixOS.
    script = ''
      /bin/mkdir /btrfs_tmp
      /bin/mount /dev/root_vg/root /btrfs_tmp
      if [[ -e /btrfs_tmp/root ]]; then
          /bin/mkdir -p /btrfs_tmp/old_roots
          timestamp=$(/bin/date --date="@$(/bin/stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          /bin/mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(/bin/btrfs subvolume list -o "$1" | /bin/cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          /bin/btrfs subvolume delete "$1"
      }

      for i in $(/bin/find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
          delete_subvolume_recursively "$i"
      done

      /bin/btrfs subvolume create /btrfs_tmp/root
      /bin/umount /btrfs_tmp
    '';
  };

  fileSystems."/persist".neededForBoot = true;
}