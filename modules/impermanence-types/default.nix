# Configuration for using Impermanence, for keeping your system clean between reboots.
# This configuration assumes you are using BTRFS, like with modules/disko-types/impermanence-btrfs.nix.
# If using sops-nix, make sure to use modules/sops-nix-types/default-impermanence.nix.
{
  inputs,
  lib,
  pkgs,
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

  boot.initrd.systemd.storePaths = with pkgs; [
    btrfs-progs
    findutils
    coreutils
    util-linux
  ];

  boot.initrd.systemd.services."impermanence-root-rollback" = {
    description = "Rollback root subvolume to empty state, archiving roots from past 30 days";

    wantedBy = [ "initrd-root-device.target" ];
    after = [ "initrd-root-device.target" ];
    before = [ "sysroot.mount" ];

    # path = with pkgs; [
    #   btrfs-progs
    #   findutils
    #   coreutils
    #   util-linux
    # ];

    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";

    script = ''
      ${pkgs.coreutils}/bin/mkdir /btrfs_tmp
      ${pkgs.util-linux}/bin/mount /dev/root_vg/root /btrfs_tmp
      if [[ -e /btrfs_tmp/root ]]; then
          ${pkgs.coreutils}/bin/mkdir -p /btrfs_tmp/old_roots
          timestamp=$(${pkgs.coreutils}/bin/date --date="@$(${pkgs.coreutils}/bin/stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          ${pkgs.coreutils}/bin/mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(${pkgs.btrfs-progs}/bin/btrfs subvolume list -o "$1" | ${pkgs.coreutils}/bin/cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$1"
      }

      for i in $(${pkgs.findutils}/bin/find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
          delete_subvolume_recursively "$i"
      done

      ${pkgs.btrfs-progs}/bin/btrfs subvolume create /btrfs_tmp/root
      ${pkgs.util-linux}/bin/umount /btrfs_tmp
    '';
  };

  # boot.initrd.postDeviceCommands = lib.mkAfter ''
  #   mkdir /btrfs_tmp
  #   mount /dev/root_vg/root /btrfs_tmp
  #   if [[ -e /btrfs_tmp/root ]]; then
  #       mkdir -p /btrfs_tmp/old_roots
  #       timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
  #       mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
  #   fi

  #   delete_subvolume_recursively() {
  #       IFS=$'\n'
  #       for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
  #           delete_subvolume_recursively "/btrfs_tmp/$i"
  #       done
  #       btrfs subvolume delete "$1"
  #   }

  #   for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
  #       delete_subvolume_recursively "$i"
  #   done

  #   btrfs subvolume create /btrfs_tmp/root
  #   umount /btrfs_tmp
  # '';

  fileSystems."/persist".neededForBoot = true;
}