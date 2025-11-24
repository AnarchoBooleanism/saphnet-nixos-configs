# Mount the NFS share for pterodactyl to a local directory
{
  ...
}:
{
  fileSystems."/mnt/pterodactyl-data" = {
    device = "nas1.int-net.saphnet.xyz:/mnt/saphnet-nas1a/pterodactyl-data";
    fsType = "nfs4";
    options = [ "nolock" "soft" "rw" ];
  };
} # TODO: Make this less hacky