# Bog-standard Fedora/Ubuntu-style disk layout, with @ and @home subvolumes (and /nix at @nix), but with a separate disk & partition for @home.
# This should allow for easy snapshots of the root filesystem, as well as the easy migration of user data between systems.
# The first disk (for non-home purposes) has the BIOS boot partition, the ESP, swap, and the btrfs partition that has / and /nix in separate subvols.
# The second disk has a btrfs partition with just the @home subvol for /home.
# This is for a VM that uses a ZFS zvol on an SSD, so CoW, checksumming, and compression are disabled
# As well, block sizes are set to 16K, the default in Proxmox.
# Much of this comes from https://github.com/nix-community/disko/blob/master/example/btrfs-subvolumes-hostzfs.nix
{
  rootDevice ? throw "Set this to your disk device, e.g. /dev/sda",
  homeDevice ? throw "Set this to your disk device, e.g. /dev/sdb",
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
      # ESP, /boot, swap, /
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
                extraArgs = [ "-f" "-n" nodeSize ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "@" = {
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/";
                  };
                  # Parent is not mounted so the mountpoint must be set
                  "@nix" = {
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/nix";
                  };
                  "@var-log" = {
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/var/log";
                  };
                };
              };
            };
          };
        };
      };
      # /home
      home = {
        type = "disk";
        device = homeDevice;
        content = {
          type = "gpt";
          partitions = {
            home = { # Referred to with the "disk-home-home" label
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-n" nodeSize ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is the same as the mountpoint
                  "@home" = {
                    mountOptions = btrfsMountOptions;
                    mountpoint = "/home";
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