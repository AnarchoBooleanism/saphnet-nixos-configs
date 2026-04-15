# Bog-standard Fedora/Ubuntu-style disk layout, with @ and @home subvolumes (and /nix at @nix), but with a separate disk & partition for @home.
# This should allow for easy snapshots of the root filesystem, as well as the easy migration of user data between systems.
# The first disk (for non-home purposes) has the BIOS boot partition, the ESP, swap, and the btrfs partition that has / and /nix in separate subvols.
# The second disk has a btrfs partition with just the @home subvol for /home.
# Much of this comes from https://github.com/nix-community/disko/blob/master/example/btrfs-subvolumes.nix
{
  rootDevice ? throw "Set this to your disk device, e.g. /dev/sda",
  homeDevice ? throw "Set this to your disk device, e.g. /dev/sdb",
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
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "@" = {
                    mountpoint = "/";
                  };
                  # Parent is not mounted so the mountpoint must be set
                  "@nix" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
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
            home = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is the same as the mountpoint
                  "@home" = {
                    mountOptions = [ "compress=zstd" "noatime" ];
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