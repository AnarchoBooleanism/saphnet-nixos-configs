# Configuration with a boot, ESP, swap, and LVM partition, based on BTRFS, designed for use with Impermanence
# The subvolumes to look out here for are / (root), /persist/, and /nix. (Don't forget about /boot too!)
# The names of their mount points should match with their subvolume names, for consistency reasons.
# Much of this comes from https://github.com/vimjoyer/impermanent-setup/blob/main/final/disko.nix
{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  ...
}:
{ 
  inputs,
  ...
} @ args: {
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
            };
          };
          swap = {
            size = "4G";
            content = {
              type = "swap";
              discardPolicy = "both"; # My proxmox nodes generally use SSDs, so yes here
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "root_vg";
            };
          };
        };
      };
    };
    lvm_vg = {
      root_vg = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];

              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                };

                "/persist" = {
                  mountOptions = ["subvol=persist" "noatime"];
                  mountpoint = "/persist";
                };

                "/nix" = {
                  mountOptions = ["subvol=nix" "noatime"];
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