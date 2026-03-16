# Guide for creating an Instance

*To review how to create a Machine for an Instance, refer to this guide*: [Guide for creating a Machine](machine-howto.md)

An Instance is an entity, or a specific, concrete realization, of a Machine, that can be directly deployed onto a system. It can be tied directly to the Machine that it references, in terms of identity, or be one of many Instances, each with its own unique identity (e.g. `docker-host-pve3` for the `docker-host` Machine). These Instances each have their own set of details unique to themselves, such as hostnames, IP addresses, and secrets. This guide will demonstrate how an Instance can be created, or instantiated, from a Machine.

## Instance fundamentals
Each Instance is generally defined in the `flake.nix` file as a NixOS configuration (an attribute set mapping names to function calls of `nixpkgs.lib.nixosSystem`), that pulls in hardware-specific Modules, Machine-specific configurations, a Constants file, and various Instance-specific files.

Here is an example, for `docker-host-core`:
```nix
{
  ... # Omitting for brevity
  outputs =
    {
      ...
    } ... {
      ...
      nixosConfigurations = {
        ...
        "docker-host-core" = nixpkgs.lib.nixosSystem { # Docker host for reverse proxy and various web services
          specialArgs = {inherit inputs outputs;};
          system = "x86_64-linux";
          modules = [
            # Config-specific files
            instances/docker-host-core/hardware-configuration.nix
            (import modules/disko-types/impermanence-btrfs.nix { device = "/dev/sda"; })
            (import machines/docker-host/configuration.nix {
              secretsFile = "${./instances/docker-host-core/secrets.yaml}"; 
              instanceValues = builtins.fromTOML (builtins.readFile "${./instances/docker-host-core/instance-values.toml}"); 
              constantsValues = builtins.fromTOML (builtins.readFile "${./constants/homelab-constants-values.toml}"); 
            })
          ];
        };
        ...
      };
    };
}
```

This starts in `outputs.nixosConfigurations` with the name of the NixOS configuration for our Instance, `docker-host-core`, which gets mapped to a functional call to `nixpkgs.lib.nixosSystem`. The function is given an attribute set that contains all the details needed for our Instance. `system` is set to `x86_64-linux`, as `control-server` is an x86_64 system, which is running Linux (NixOS). Finally, it is given a list of modules, Nix files, that will be put together to form the complete configuration for our system; importantly, this is the location where Modules specific to an Instance, and not just a Machine, are pulled in. These modules, the details of all which will be covered in the next section of the guide, include a Nix configuration for the specific hardware for the Instance, a Module with the Disko configuration that will be used, with `device` set to `/dev/sda` (for a single SCSI disk setup), and the main Nix configuration for the Machine, `docker-host`, with multiple Instance-specific and Constants-specific files being pulled into the configuration. Note that some files are imported with the `import` syntax; this is because some of the Nix files are curried functions, which have the outer function take in arguments, such as names and file paths, and return the inner function, with all the details filled in, that `nixos.lib.nixosSystem` can call.

Note that the choice of Disko configuration being imported as a module is highly important: it should match the disk configuration of the target system (e.g. the number of disks), and have any desired features that the Machine or any applications rely on (e.g. btrfs); furthermore, if the Machine uses Impermanence, the Disko configuration must specifically support it, with a specific volume for persistent files.

The main path to existence for an Instance is in the `flake.nix` file, being a named NixOS configuration, where all of the necessary details are given, from the modules to the Instance-specific files, so that a Nix builder has everything that it needs to build a complete flake and provision the system. However, for an Instance, more is needed than an entry in `flake.nix`: it needs both Constants-specific files and Instance-specific files, both of which will be expanded upon in the next sections of this guide.

## Constants-specific files

*This is covered in more detail in this writeup*: [Explanation of the repository](explanation.md)

Before covering Instance-specific files, we will first cover Constants-specific files. Constants are simply groups of constant values, such as timezones and authorized SSH keys, common across multiple Instances/Machines, which may share certain characteristics or needs; Constants exist to avoid unnecessary repetition. When creating/importing Constants, make sure that it has all of the values that the Machine may need. Files that contain Constants are generally in TOML format.

Here is an example of a Constants file, in `homelab-constants-values.toml`, for all Machines/Instances that run in the Sapphic Homelab/Home Server:
```toml
# homelab-constants-values.toml
# A list of defaults to use for any homelab-related machine

default-username = "saphnet-user"
authorized-keys = [ # Try to rotate these every now and then...
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHYjHkLEoqnhIg91FVA32nL7qbJe2l+Iy+t/WX98z7td hihacks@valk-pc", # Directly via personal computers
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBb79Z1HFfgBM2XVyURzsXRG0b0fJRNplyN3v80CF8j hihacks@crummytop",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC03O18a2GH5euD1k5mKW67mC04m1GyvmgymxOqrCypH saphnet-ansible-playbook" # Ansible
]
timezone = "America/Los_Angeles"

[networking]
gateway = "192.168.8.1"
subnet = "192.168.8.0/23"
nameservers = ["8.8.8.8", "8.8.4.4", "1.1.1.1"]

[email]
address = "homelab@saphnet.xyz"
host = "mail.privateemail.com"
port = "465"
``` 

This set of Constants includes, in the top-level keys, values for items such as usernames and timezones. There are also sections for different sets of values, such as `networking`, which contains network-specific information that is shared for all nodes in the network, as the network is the same for all machines in the Sapphic Homelab/Home Server. These values, combined with all of the values from the Instance-specific files, provide all of the information that is needed to provision an Instance.

Many Machines require that an attribute map of Constants is given via `constantsValues` in their outer functions. To do that, make sure the path to the Constants file is given to `builtins.readFile`, with the contents read by this function fed to `builtins.fromTOML`, which will parse it into the attribute map that the Machine will take in. This is an example of how this can be done, as shown in `docker-host-core`:

```nix
"docker-host-core" = nixpkgs.lib.nixosSystem { # Docker host for reverse proxy and various web services
    ...
    modules = [
    ...
    (import machines/docker-host/configuration.nix {
        ...
        constantsValues = builtins.fromTOML (builtins.readFile "${./constants/homelab-constants-values.toml}"); 
    })
    ];
};
```

Constants allow for many types of values to be shared among multiple Machines/Instances, with only one source of truth that can be changed, allowing for reduced repetition; they provide, to Machines, much of the information that is needed to completely provision an Instance. With Constants covered, as well as how to import them, we will next cover the files that are used for specific Instances.

## Instance-specific files

With an Instance are many files that contain important configurations and values that an Instance will need to be provisioned with. These include the `hardware-configuration.nix` file, files for Secrets, and the main file for an Instance's values. They generally are in an Instance-specific subdirectory in the `instances` directory. This section will cover each of the files that an Instance will need.

### hardware-configuration.nix
`hardware-configuration.nix` is a Nix configuration that describes the different modules and settings that are needed for the hardware on which the Instance will run. This includes kernel modules and host platform details.

Here is an example of `hardware-configuration.nix` for the `docker-host-core` Instance:
```nix
# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

This adds modules that are used for QEMU guests, as the Instance is intended to be run as a KVM-based virtual machine; this also defines settings such as kernel modules and settings, and networking details for the interface specific to the system.

Note that this file should be automatically generated by `nixos-generate-config` (which is usually called by `nixos-anywhere` in our guides), and shouldn't be touched otherwise; you are welcome to bring the results generated by `nixos-generate-config` to the Git repository, however. For any new Instance, simply create a placeholder configuration that will throw if actually evaluated, like this:
```nix
throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-generate-config ./hardware-configuration.nix`?"
```

This file will need to be directly imported as a module in our entry in nixosConfigurations in the `flake.nix` files.

### Secrets files
Generally, any Instance that will be accessible by other machines, has to call external services with specific tokens, or is otherwise long-lived will need to store specific values as secrets, and have a place to store these secrets. These secrets can include values such as passwords, password hashes, tokens, and API keys. This is usually in the form of a `secrets.yaml`, a YAML file with values that are automatically encrypted with sops, and will automatically be imported by sops-nix.

Before creating a secrets file, you will first need to have an entry for it in the `.sops.yaml` file in the root of the repository, as well as a age keypair to be used with sops by the Instance.

To create a age keypair (for the Instance), run this command: `nix shell nixpkgs#age --command age-keygen -o <DESIRED PATH TO AGE KEY>`

The resulting file will contain the private key, as well as a public key (usually). The command should also have printed the public key to the console. Make sure to save this file/private key somewhere, as it will be needed when deploying the Instance later, as `[/persist]/var/lib/sops-nix/keys.txt`!

In the `.sops.yaml` file, we add lines with the public key of the Instance, as well as an entry for our secrets file, like in this example for `docker-host-core`:
```yaml
keys:
  - &admin age1ute399nzja7le5um48rzdg2nj4c7rf5jvhj7slh05mt5x79nr4wqqlwkdj
  ...
  - &docker-host-core age16tx7kzg6fs9qr5t2hyjqnx9clp7vgkkh97qjrzfuldc887jxv4ts2rsaeh
  ...
creation_rules:
  ...
  - path_regex: instances/docker-host-core/secrets.yaml # docker-host-core
    key_groups:
    - age:
      - *admin
      - *docker-host-core
  ...
```

In `keys`, we have a value for the name of our Instance, `docker-host-core`, the name being prefixed with `&` to make the value an anchor, so that references to the anchor resolve to the specific key.

In `creation_rules`, we have an entry for our secrets file. This entry has the `path_regex` attribute, which is the relative path from the root of the repository to the secrets file for our Instance. This also has the `key_groups` for our attribute, with an entry with the `age` attribute, that lists the key of `admin`, as well as our Instance, `docker-host-core`.

Note that we also have a specific age key for `admin`, and that `admin` is in the list of age `key_groups` for our entry for `docker-host-core`. The way that sops works is by encrypting the secrets file multiple times for each key, in separate locations. The key for `admin` is listed, so that we can modify the secrets file oureslves; make sure that you have an age key in `$HOME/.config/sops/age/keys.txt`, which should be the same one listed in `keys` in the `.sops.yaml`.

With an entry in the `.sops.yaml` file present, we are now able to create and edit our secrets file. We will need to run sops with the `edit` command to do so, like this: `EDITOR=nano nix run nixpkgs#sops -- edit ./instances/INSTANCE-NAME/secrets.yaml`

If successful, you should have the file open and editable. You are now welcome to add your secrets, as mappings of keys to values, in the YAML format, like this (note that this is not an actual file that is present in the repository):
```yaml
main-password-hashed: $6$Z3KN0Zei8bXbemfA$rc7n4eU86i/YQOQL2ZqNBg4uyf3QZ3hlpZSI6T6w1VqL2u94nh0RnnOar4ApGEfEyCoOcdiL./XrrVHPzKuHf1
my-api-key: myapikeyhere_123456789abcdef123
```

If you are unsure of what secrets to add, start with all of the secrets values that are referred to in the Machine configuration and its Modules (e.g. `main-password-hashed`).

Once you exit the editor, you should see that the resulting file has many of the same key names as above, but with the values encrypted, as well as some other information for sops to use. If you want to edit the file again, use the same `sops edit` command as before (and make sure the key for `admin` is in `$HOME/.config/sops/age/keys.txt`).

If you wish to decrypt or encrypt the file directly, you can run the commands  `nix run nixpkgs#sops -- decrypt --in-place ./instances/INSTANCE-NAME/secrets.yaml` and `nix run nixpkgs#sops -- encrypt --in-place ./instances/INSTANCE-NAME/secrets.yaml` respectively.

#### On creating password hashes
It is generally best practice to have a NixOS flake use a password hash, as opposed to a plaintext password, to make it harder for potential attackers on the system to obtain it. Furthermore, Machines are generally set up to use password hashes; be sure to save the actual passwords somewhere secure.

To create a password hash, enter your desired password as input in this command: `nix run nixpkgs#mkpasswd -- -m sha-512 -s`

This password hash is usually written as a value for the secret `main-password-hashed`.

With all of our secrets now configured with sops, we can now cover the main configuration file for an Instance, `instance-values.toml`, where many important values for an Instance are set.

### Instance configuration

The core of an Instance's configuration is the `instance-values.toml` file. In the TOML format, it is a set of values for a specific Instance that determine the Instance's identity, like with the hostname and IP address, what system and hardware-specific options to pick, and, if applicable and for Instances that are one of many for a Machine, what differentiates each Instance. Here is an example of the `instance-value.toml` for the `docker-host-core` Instance:
```toml
# instance-values.toml
# A list of values to use to instantiate docker-host for docker-host-core

hostname = "docker-host-core"
domain = "int-net.saphnet.xyz"

[networking]
ip-address = "192.168.8.202" # docker-host-core.int-net.saphnet.xyz
ip-prefix-length = 23 # 192.168.8.0/23
interface = "ens18"
```

This TOML config is very simple: it defines the FQDN of the Instance (the host), with `docker-host-core` being the main hostname, and the domain being `int-net.saphnet.xyz`, the IP address & prefix length (`192.168.8.202/23`), and the specific interface to bind to with the IP address (`ens18`, the general default for a Linux VM under Proxmox). Most `instance-values.toml` files will have at least these specific values, if they do not have the exact same structure, but be sure to consult the Machine configuration file and its Modules for any other values that are referred and need to be defined in this file.

With all of the files that are needed to complete an Instance all set up, from the secrets file to the `instance-values.toml` file, we are now able to successfully deploy the Instance to an actual system.

## Final words

The Instance is the concrete, realized version of a Machine in the scope of this repository; it is the final step we need to make before we can deploy an actual system. Being defined at the place where NixOS configurations are defined in the flake, it is the location where Modules that bridge the gap between the Machine and the target hardware are imported; it is also where the files with values specific for the Instance are imported, allowing the Instance to have a unique identity beyond the simple instantiation of a Machine. Furthermore, an Instance is relatively simple to set up, with only a few small files and extra lines of code to write. With an Instance now defined, we are finally able to deploy this Instance to an actual system.

With an Instance now defined, here is a guide on deploying it to a real system: [Guide for deploying an Instance](deployment-howto.md)