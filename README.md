# saphnet-nixos-configs
A set of NixOS configuration files for various machines/VMs within the Sapphic Homelab/Home Server

> NOTE: You might want to interact with this through the Ansible playbook, see here: [saphnet-ansible-playbook](https://github.com/AnarchoBooleanism/saphnet-ansible-playbook)

Hello! These are the various configuration files for the NixOS machines within the Sapphic Homelab/Home Server, with different sections for instances (the values for actual machines), machines (blueprints for actual machines, to be instantiated), and the different modules that the machines use. These are designed to be deployed to virtual (and bare-metal) machines using `nixos-anywhere` and `nixos-rebuild`, indirectly through Ansible ([see my Ansible playbook](https://github.com/AnarchoBooleanism/saphnet-ansible-playbook)).

It is recommended that you use [nixos-cloud-init-installer](https://github.com/AnarchoBooleanism/nixos-cloud-init-installer), in combination with a cloud-init drive, as a driver to deploy these configuration files with `nixos-anywhere`.

The configuration files are inspired by god464's [flake](https://github.com/god464/flake), Swarsel's [.dotfiles](https://github.com/Swarsel/.dotfiles/), Misterio77's [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs), and nix-community's [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples), among many, many other NixOS configuration repositories.

### Index of contents (of the documentation):
- [Explanation of the repository](docs/explanation.md)
- [Guide for creating a Module](docs/module-howto.md)
- [Guide for creating a Machine](docs/machine-howto.md)
- [Guide for creating an Instance](docs/instance-howto.md)
- [Guide for deploying an Instance](docs/deployment-howto.md)
- [Style guide for writing and structuring configuration files](docs/style-guide.md)
- Machine-specific write-ups
  - [control-server (first and most important machine to deploy!)](machines/control-server/README.md)

### Useful commands
Here are some useful commands to use when writing to the configuration and deploying to machines:

- For editing SOPS secrets files: `EDITOR=nano nix run nixpkgs#sops -- edit ./machines/SERVER-NAME/secrets.yaml`
  - NOTE: Make sure your age private key is in `~/.config/sops/age/key.txt`! Otherwise, make sure to set one of the environment variables `SOPS_AGE_KEY_FILE`, `SOPS_AGE_KEY`, or `SOPS_AGE_KEY_CMD` to your desired value beforehand.
- For doing fresh installs: `nix run github:nix-community/nixos-anywhere -- --flake .#<INSTANCE_NAME> --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --target-host root@<IP ADDRESS/HOSTNAME>`
  - NOTE: Again, you'll generally want to perform this task through [saphnet-ansible-playbook](https://github.com/AnarchoBooleanism/saphnet-ansible-playbook), which handles the particulars of this command for you.
  - If you want to specify an SSH private key to use to connect to the remote host, make sure to add the following to the command: `-i <PATH TO SSH PRIVATE KEY>`
  - If you have extra files you want to add to your target system, make sure to add the following to the command: `--extra-files <PATH TO DIRECTORY WITH EXTRA FILES>`
- For creating the hash of a password (store this as a secret): `nix run nixpkgs#mkpasswd -- -m sha-512 -s`
- For creating an age key from scratch: `nix shell nixpkgs#age --command age-keygen -y <DESIRED PATH TO AGE KEY>`
  - For `-o`, you'll probably want to store this in `$HOME/.config/sops/age/keys.txt`
- For obtaining an age key from an SSH key (it needs to be an ed25519 key, not RSA): `nix run nixpkgs#ssh-to-age -- -private-key -i <PATH TO SSH PRIVATE KEY> -o <DESIRED PATH TO AGE KEY>`
  - NOTE: If you have a passphrase for the SSH key, make sure to set the environment variable `SSH_TO_AGE_PASSPHRASE` beforehand! The best way to do this is with the command `read -s SSH_TO_AGE_PASSPHRASE; export SSH_TO_AGE_PASSPHRASE`
  - For `-o`, you'll probably want to store this in `$HOME/.config/sops/age/keys.txt`

### Note on using Nix
In order to deploy and do other tasks with the contents of the repository, you'll want to have Nix available, with both flakes and nix-commands enabled.

There are a few ways you can do this:
- You can install Nix via your distro's package manager, and then in `/etc/nix/nix.conf`, you add this line: `experimental-features = nix-command flakes`
- You can use Determinate Nix, which comes with both features enabled out of the box: [Determinate Nix | Determinate Systems](https://docs.determinate.systems/determinate-nix/)
- In a pinch, if you have Docker installed, you can just load into the NixOS image with Nix included, with `docker run -it --rm nixos/nix`, and then enable both features by running `echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf`

### Useful links
Links that have helped with the creation of this repository:
- https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/
- https://bmcgee.ie/posts/2022/11/getting-nixos-to-keep-a-secret/