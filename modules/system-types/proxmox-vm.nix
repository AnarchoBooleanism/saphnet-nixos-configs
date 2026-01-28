# Setup configured to work best for servers running as VMs on Proxmox
{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Various tools for system management
    nfs-utils
    pciutils
    python314
    vim
    man-db
    git
    curl
    rsync
    htop
    bash-completion
    dmidecode
    ncdu
  ];

  boot.initrd = { # Support nfs systems
    supportedFilesystems = [ "nfs" "nfsv4" "overlay" ];
    kernelModules = [ "nfs" "nfsv4" "overlay" ];
  };

  # GRUB bootloader
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # Enable serial console, for direct access
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty1"
  ];

  # SSH server, for headless access
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };
  programs.ssh.startAgent = true; # Nicety for control server

  # Other tools for integrating with Proxmox
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # Security-related items
  security.apparmor.enable = true;
  services.fail2ban.enable = true;
}