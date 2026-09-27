# Configuration with a boot, ESP, and swap, based on BTRFS, designed for use with Impermanence
# The subvolumes to look out here for are @ (root), @persist, and @nix. (Don't forget about /boot too!)
# The names of their mount points should match with their subvolume names, for consistency reasons.
# Much of this comes from https://github.com/vimjoyer/impermanent-setup/blob/main/final/disko.nix
{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  ...
}:
{ 
  inputs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
  ];

  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            size = "4G";
            content = {
              type = "swap";
              discardPolicy = "both"; # My proxmox nodes generally use SSDs, so yes here
            };
          };
          root = { # Referred to with the "disk-root-root" label
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                };
                "@persist" = {
                  mountOptions = ["noatime"];
                  mountpoint = "/persist";
                };
                "@nix" = {
                  mountOptions = ["noatime"];
                  mountpoint = "/nix";
                };
              };
            };
          };
        };
      };
    };
  };
}