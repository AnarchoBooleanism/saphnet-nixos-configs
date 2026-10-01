# Configuration with a boot, ESP, and swap, based on BTRFS, designed for use with Impermanence
# Highly recommended to use for VMs!
# Dual-disk setup, with one disk for persistent data (between installs), and another disk for
# everything else.

# The subvolumes to look out here for are:
# - @ (root),
# - @nix (/nix)
# - @persist (/persist)
# - @persist-data (/persist-data) 
# (Don't forget about /boot too!)
# NOTE: @persist-data is on a separate disk (dataDevice).
# This allows you to only back up that disk, and be able to have your data back after a reinstall.

# Note that there is no /home directory, as this is intended for non-user-facing systems.

# Persistent data is split between these two kinds:
# - Data that should be persistent between restarts, but not reinstalls (in @persist)
# - Data that should be persistent between restarts AND reinstalls (in @persist-data)

# This is for a VM that uses a ZFS zvol, so CoW, checksumming, and compression are disabled.
# As well, block sizes are set to 16K, the default in Proxmox.

# Much of this comes from https://github.com/vimjoyer/impermanent-setup/blob/main/final/disko.nix

{
  rootDevice ? throw "Set this to your disk device, e.g. /dev/sda",
  dataDevice ? throw "Set this to your disk device, e.g. /dev/sdb",
  ...
}:
{ 
  inputs,
  ...
}:
let
  btrfsMountOptions = [
    "discard=async"
    "noatime"
    "nodatacow"
    "nodatasum"
    "space_cache=v2"
    "ssd"
  ];
  nodeSize = "16k"; # 16K is the default Proxmox ZFS block size
in
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  disko.devices = {
    disk = {
      root = {
        type = "disk";
        device = rootDevice;
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
                extraArgs = [ "-f" "-n" nodeSize ];
                subvolumes = {
                  "@" = {
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/";
                  };
                  "@nix" = {
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/nix";
                  };
                  "@persist" = { # Persistent between just restarts
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/persist";
                  };
                };
              };
            };
          };
        };
      };
      # /data
      data = { # Persistent between restarts AND reinstalls
        type = "disk";
        device = dataDevice;
        content = {
          type = "gpt";
          partitions = {
            data = { # Referred to with the "disk-data-data" label
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-n" nodeSize ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is the same as the mountpoint
                  "@persist-data" = { # This should also be marked with Impermanence
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/persist-data";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}