# Configuration with a boot, ESP, swap, and a root partition, BIOS-compatible (good for default Proxmox VM)
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
            };
          };
          swap = {
            name = "swap";
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
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}