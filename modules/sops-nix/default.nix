# Configuration for sops-nix, written to work WITHOUT Impermanence
# NOTE: Make sure secretsFile is set to the path of a valid yaml file!
# Furthermore, this file needs to inherit both secretsFile and inputs from your
# configuration file importing this file.
# To do this, in your imports section, import this file like this:
# (import (../.. + "/modules/sops-nix/default-impermanence.nix") {
#   inherit inputs secretsFile;
# }) 
{
  inputs,
  secretsFile,
  ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = secretsFile;
    defaultSopsFormat = "yaml";

    age = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
      ];
      keyFile = "/var/lib/sops-nix/keys.txt";
    };

    gnupg = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_rsa_key"
      ];
    };

    # Make sure you set sops.secrets in your configuration.nix file!
    # NOTE: If any of your secrets are Linux user passwords, make sure you set
    # neededForUsers as true for that secret!
  };
}