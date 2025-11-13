# Explanation of the repository

All NixOS configurations are defined in `flakes.nix`, which we can use in `nixos-anywhere` and `nixos-rebuild`. To create these configurations, our settings are divided into various components that serve as building blocks to create any system (and kind of system), in a way that is modular, scalable, and versatile: we have the Module, the Machine, the Instance, and Constants. Modules are put together to create a Machine (essentially, a blueprint for a system), which is then instantiated with an Instance, to make a NixOS configuration, alongside other values from a set of Constants. This guide is an explanation of how the repository is structured, and an explanation of the components and groups of files that are used to create NixOS configurations.

## The repository's structure

- `modules` - This is where each Module is stored, with each Module being its own subdirectory. Each subdirectory has one or more `.nix` files, at least one or more of which are configurations files that can be directly imported by a Machine.
Here is the overall structure of each main directory and file of the repository:
- `machines` - This is where each Machine is stored, with each Machine being its own subdirectory. Each subdirectory generally consists of a `configuration.nix` file (or a variety of one), which is the main configuration file that can be imported into `flake.nix`, a `hardware-configuration.nix` file, which is either a stopgap file or an automatically-generated one, a `version-lock.toml` file, which describes NixOS's `stateVersion`, as well as the versions/hashes of Docker images and other non-Nix packages (for the sake of reproducibility), and other files that are imported by `configuration.nix` that are needed for certain functionality. They can also contain their own `README.md` files, for Machine-specific details and functionality.
- `instances` - This is where the details of each Instance is stored, with each Instance having its own subdirectory. Each subdirectory generally consists of secrets and Instance values files, which can then be imported when instantiating a Machine (as a NixOS configuration) in `flake.nix`.
- `constants` - This is where each group of Constants are stored, with each group being its own TOML file.
- `.github` - This is where GitHub-specific configuration files are stored, for GitHub Actions and Dependabot.
  - `workflows` - These contain YAML files that describe workflows for GitHub Actions to perform, such as creating builds or automatically updating files.
  - `dependabot.yml` - This describes the Dependabot configuration, which automatically suggests updates for packages and dependencies, such as for GitHub Actions, but not including Nix.
- `docs` - This contains most of the documentation for this repository, written as Markdown.
- `.gitignore` - This file describes the names of files and directories for Git to ignore when tracking files.
- `.sops.yaml` - This file contains the information needed for sops to work in this repository, including the names of keys, and where secrets files are located.
- `flake.lock` - This file contains the versions and hashes of repositories, packages, and dependencies that NixOS installers and rebuilders will install onto systems.
- `flake.nix` - This file describes all Instances as NixOS configurations, which pull the various Instance, Machine, and Constants files that are needed for instantiating Machines. This file also describes the versions of the repositories and dependencies used for systems.
- `LICENSE` - This file describes the license being used for this repository, which is the CC0 1.0 Universal.
- `README.md` - This file is the central starting point for this repository's documentation.

## Modules

*More on how to create a Module*: [Guide for creating a Module](module-howto.md)

Modules are NixOS configuration files with common settings and functionality useful for various Machines. They are the main building blocks for a Machine, allowing Machines to be compositions of Modules for combining different kinds of functionality. For example, Modules can define packages and settings that are useful for specific kinds of Machines, like using `qemu-guest-agent` for Proxmox VMs; they can also be used to configure specific pieces of functionality, like configuring Docker support, or Tailscale support.

Modules are organized into subdirectories by types of functionality, and there can be different varieties of Modules for different needs and types of systems in the same category/subdirectory. Modules can also rely on other Modules, so that common settings can be shared, while differences between Modules still can be easily set.

They can be imported inside a Machine's `configuration.nix`, or imported alongside it in `nixosConfigurations` in `flake.nix`, if it is functionality that doesn't need to be part of the Machine, but rather something specific to an Instance or something done during provisioning; for example, Disko Modules are generally imported in `nixosConfigurations` in `flake.nix`.

**NOTE:** Modules are files with functionality that can be shared among Machines, and aren't tied to the inner workings of a specific Machine; if the workings of a specific set of settings and services can't be cleanly separated from a Machine, it should not be made into a Module.

Here is an example of a Module, for configuring Machines that are meant to be run as virtual machines within Proxmox, `<REPO>/modules/system-types/proxmox-vm.nix`:
```nix
# modules/system-types/proxmox-vm.nix
# Setup configured to work best for servers running as VMs on Proxmox
{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Various tools for system management
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

  # Other tools for integrating with Proxmox
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # Security-related items
  security.apparmor.enable = true;
  services.fail2ban.enable = true;
}
```

This file defines different packages that are useful for headless VMs, like `man-db` and `git`, a bootloader that works for VMs that don't use UEFI, kernel parameters for enabling a serial console, settings for OpenSSH (for headless access), as well as other settings and services that help with Proxmox integration and security.

Here is another example of a Module, for Tailscale functionality, `<REPO>/modules/networking/tailscale.nix`:
```nix
# Tailscale config, with space for different names and such
{
  config,
  pkgs,
  ...
}:
let
  tailscalePort = 41641; # Set Tailscale port here, default is 41641
in
{
  environment.systemPackages = with pkgs; [
    tailscale
  ];

  # services.tailscale.enable = true;
  # services.tailscale.port = tailscalePort;
  services.tailscale = {
    enable = true;
    port = tailscalePort;
    authKeyFile = "${config.sops.secrets.tailscale-auth-key.path}";
  };

  # Configure firewall (if relevant)
  networking.firewall.allowedUDPPorts = [ tailscalePort ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
```

This file defines various variables and values, enables the Tailscale service, and configures the firewall to work best with Tailscale. Notably, this takes in input in a way that allows indirectly passing in sops secrets from the Machine's `configuration.nix` file, which allows for easy instantiation of Machines into Instances.

Simply by being reusable snippets of NixOS configurations, Modules are very useful for creating any Machine, and are very easy to define, too. Now that we know about Modules, how they're made, and what they do, we can move to learning about how to make Machines with them.

## Machines

*More on how to create a Machine*: [Guide for creating a Machine](machine-howto.md)

A **Machine** is a template for a NixOS configuration, which can take in values as parameters, in the form of file paths and parsed TOML files, to be instantiated into an Instance; a Machine is analogous to a class in object-oriented programming. It is generally composed of other Modules, as well as Machine-specific services and other settings that define what the Machine is and what it does. That being said, a Machine doesn't necessarily need to be designed to be instantiated into multiple Instances at once; it can be designed to be a singleton, too.

Each Machine generally has its own subdirectory in `<REPO>/machines`, and each subdirectory (e.g. `control-server`) has multiple files involved in the overall NixOS configuration and any services on top of the main configuration. This subdirectly generally includes files such as `hardware-configuration.nix`, which is generally auto-generated by `nixos-anywhere`, and `version-control.yaml`, which contains NixOS's `stateVersion` and the versions and hashes of relevant non-NixOS packages (e.g. Docker images).

The most important file in this subdirectory, though, is `configuration.nix`, which is the central Nix configuration file for the Machine itself. This file is what is imported by `flake.nix`, alongside any Instance-related files, to form a specific NixOS configuration, which defines a Instance.

Here is an example of how `flake.nix` imports the `configuration.nix` file of a specific Machine when defining an Instance as a NixOS configuration:
```nix
# flake.nix
{
  ...
  outputs =
    { self, nixpkgs, ... } ...: ... {
      nixosConfigurations = {
        "control-server" = nixpkgs.lib.nixosSystem { # control-server is the name of the Instance, which instantiates the mononymous control-server Machine
          ...
          modules = [
            machines/control-server/hardware-configuration.nix # This is the hardware-configuration.nix file for the Machine, auto-generated when nixos-anywhere is started
            (import modules/disko-types/impermanence-btrfs.nix { device = "/dev/sda"; }) # This is the specific disk partition layout used for the Instance, generally oriented for a particular Machine
            (import machines/control-server/configuration.nix { # This is where the control-server Machine's specific configuration.nix file is imported
              secretsFile = "${./instances/control-server/secrets.yaml}"; # These are the various files imported and used as arguments when importing the configuration.nix file
              instanceValues = builtins.fromTOML (builtins.readFile "${./instances/control-server/instance-values.toml}"); 
              constantsValues = builtins.fromTOML (builtins.readFile "${./constants/homelab-constants-values.toml}"); 
            })
          ];
        };
      };
  };
}
```

In `outputs.nixosConfigurations`, through the `nixosSystem` function, `control-server` is defined through multiple Nix files, imported as modules. The Machine's auto-generated `hardware-configuration.nix` file is imported, then a specific disk layout configuration file used by Disko to partition the system's disk, and, finally, the Machine's `configuration.nix` file is imported, with the contents of different Instance-related files being passed in as arguments to `configuration.nix`, instantiating it.

Delving into `configuration.nix`, this main configuration file is a two-layered curried function. In the first layer of the function, custom parameters (e.g. `secretsFile`) are taken with values that are used to instantiate a Machine. In the second layer of the function (the main part of the function), various parameters are taken that are generally passed in by `nixpkgs.lib.nixosSystem` (e.g. `pkgs`). The final output of this function, which defines a specific NixOS configuration (also known as an Instance), is composed of various components: imported modules, which include built-in NixOS modules and this repository's Modules, `let` statements that defined Machine-specific values that are commonly used between different settings (e.g. `versionLock`), and the different NixOS settings themselves, for the configuration.

What most defines the Machine are the Modules that it takes in, which define blocks of different functionality, and its individual configuration settings, which include the services and programs that the Machine hosts. These settings define everything from networking settings and user settings, to ones that define systemd services. 

Here is an example of a `configuration.nix` file, for `control-server`:

```nix
# machines/control-server/configuration.nix
{ # Custom parameters for instantiating this Machine
  secretsFile ? throw "Set this to the path of your instance's secrets file",
  instanceValues ? throw "Set this to the contents of your instance's values file",
  constantsValues ? throw "Set this to the contents of a constants values file",
}:
{
  pkgs, # Inputs given by nixpkgs.lib.nixosSystem, used by this configuration
  ...
}:
let
  versionLock = lib.importTOML ./version-lock.toml;
  ...
in
{
  imports = [ # The Modules with functionality that this configuration pulls in
    # NixOS modules
    ...
    (modulesPath + "/profiles/qemu-guest.nix")
    # Internal repository Modules
    (../.. + "/modules/nix-setup-types/default.nix")
    (../.. + "/modules/system-types/proxmox-vm.nix")
    ...
    (../.. + "/modules/virtualization/docker.nix")
    (../.. + "/modules/networking/tailscale.nix") # <- An example of a Module, for Tailscale functionality
  ];

  networking.hostName = instanceValues.hostname; # Examples of different settings for this Machine, which pull in from Instance and Constants values
  networking.domain = instanceValues.domain;
  networking.defaultGateway = constantsValues.networking.gateway;

  # An example of a systemd service, which starts the Docker Compose file for the Komodo service
  systemd.services."komodo-control" = {
    description = "Control server for Komodo";

    wantedBy = ["multi-user.target"]; # Various settings for the timing of the service
    wants = ["network-online.target"];
    after = [
      "docker.service"
      ...
    ];

    environment = { # Environment variables that are taken in for the service
      ...
      ENV_FILE = "${./komodo-control/compose.env}";
    };

    script = with pkgs; '' # The shell script ran by this service, which runs various commands
      ...
      ${pkgs.docker}/bin/docker compose -p komodo -f ${./komodo-control/mongo.compose.yaml} --env-file ${./komodo-control/compose.env} up
    '';
  };

  system.stateVersion = "${versionLock.state-version}"; # An example of a setting using versionLock
}
```

This `configuration.nix` file first takes in custom parameters, secretsFile, instanceValues, and constantsValues, that are used for turning this first layer of the function from a Machine to an Instance that can be used as a NixOS configuration. Then, more parameters are taken in, which should be given by `nixpkgs.lib.nixosSystem`, which define some inputs that are commonly used across the configuration. Once we reach the main part of the configuration, we start with different imports for various modules, which include Modules that define settings and functionality common among certain kinds of systems, as well as Modules that define specific sets of functionality, like the Modules that enable Docker and Tailscale functionality. Finally, different settings that described how this specific Machine functions and acts, like for networking and systemd services are defined.

Machines are the core of this NixOS configuration repository, which define almost everything that a specific type of system does and the core of what any system is. Now that we know what Machine is, we will need to bridge the gap to defining a NixOS configuration, with the Instance.

## Instances

*More on how to create an Instance*: [Guide for creating an Instance](instance-howto.md)

An **Instance** is a specific NixOS configuration, with its own entry in `outputs.nixosConfigurations` in `flake.nix`, which is usually created from a Machine, instantiated with Instance-specific values and files; it is analogous to an object (or instance) in object-oriented programming. They generally have their own values for their specific identities, such as in terms of networking; these usually are for items like IP addresses and hostnames.

Each Instance has its own subdirectory in `<REPO>/instances` for Instance-specific values and settings, usually coming with an `instance-values.toml` file, for non-secret values (e.g. hostnames), and a `secrets.yaml` file, for secret values (e.g. passwords). These files, alongside a Constants file, are imported when importing a Machine into `outputs.nixosConfigurations` in `flake.nix`.

Here is an example of how an Instance is defined as a NixOS configuration in `flake.nix`:
```nix
{
  ...
  outputs =
    {
      self,
      nixpkgs,
      ...
    } @ inputs: let
      inherit (self) outputs;
    in {
      nixosConfigurations = {
        ...
        "control-server" = nixpkgs.lib.nixosSystem { # Control server for Komodo
          specialArgs = {inherit inputs outputs;};
          system = "x86_64-linux"; # This defines the architecture of the Instance
          modules = [
            machines/control-server/hardware-configuration.nix # This should be auto-generated by nixos-anywhere for the Machine
            (import modules/disko-types/impermanence-btrfs.nix { device = "/dev/sda"; }) # This is the Instance's specific disk layout
            (import machines/control-server/configuration.nix { # The Machine is instantiated here, being turned into a NixOS configuration that can be taken in by nixpkgs.lib.nixosSystem itself
              secretsFile = "${./instances/control-server/secrets.yaml}"; # These are the Instance-specific values used to instantiate the Machine
              instanceValues = builtins.fromTOML (builtins.readFile "${./instances/control-server/instance-values.toml}"); 
              constantsValues = builtins.fromTOML (builtins.readFile "${./constants/homelab-constants-values.toml}"); 
            })
          ];
        };
      };
    };
}
```

In this file, `control-server` is an entry defined in `outputs.nixosConfiguration` as a NixOS configuration (and an Instance), with the `x86_64-linux` system type, with modules consisting of `hardware-configuration.nix`, the Instance's disk layout, and the `configuration.nix` file of a Machine, with the Instance's specific values fed into it, which can all be fed into `nixpkgs.lib.nixosSystem` to be turned into something that can be made as a real system.

Here is an example of `instance-values.toml`, for `control-server`:
```toml
# instance-values.toml
hostname = "control-server"
domain = "int-net.saphnet.xyz"
authorized-keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHr+c+avIdfIU4xGN6zPh1Yjmse6L4e8f98j4JWX4lmi hihacks@valk-pc",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILC3RtnBmFqCn1qZuMXbQDVQqW2qJh0Z/Mspxc2Accrd hihacks@crummytop"
]

[networking]
ip-address = "192.168.8.211" # control-server.int-net.saphnet.xyz
ip-prefix-length = 24 # 192.168.8.0/24
interface = "ens18"
```

This defines various values (that can be publicly shared as cleartext) that make the Instance unique, with its own identity; these include the hostname, domain, authorized SSH public keys, IP address, alongside other values that are unique to the Instance.

Here is an example of `secrets.yaml`, for no machine in particular reason (as cleartext):

```yaml
my-very-secret-password: password123
my-very-secret-certificate: | # This is a multi-line secret
  ----- START CERT HERE -----
  this-is-not-a-real-certific
  ate-but-here-you-go-thanks
  ------ END CERT HERE ------
```

These define different kinds of secrets, which will be encrypted using the keys in `.sops.yaml`. This file will be passed in when the Machine is instantiated, and its individual values will be passed into the Machine (via file paths) for use in various services.

NOTE: If you take a look at `secrets.yaml` without decrypting it first, you will get something that does not look like the example above, instead being seemingly-garbled text. To edit an encrypted file (or write a new one), use this command: `EDITOR=nano nix run nixpkgs#sops -- ./instances/control-server/secrets.yaml`

With Instances, we can harness the power of each Machine in a form that can be deployed via `nixos-anywhere` (or `nixos-rebuild`). Of course, there are different values that aren't just specific to any particular Instance or any particular Machine, but also can be shared across multiple Instances/Machines, going into the territory of the Constants, which we will learn about before wrapping up this guide.

## Constants
Constants are groups of constant values, common across multiple Instances/Machines, which may share certain characteristics or needs, that can be applied to multiple Instances/Machines, in contrast to Instance values, which are unique values for particular systems. This allows us to not need to repeat common values for different Instances/Machines, and allows us to only need to edit one file to affect multiple systems in certain groups. Generally, the values in question are ones like timezones, usernames, and networking details for particular networks. Constants are generally stored as individual TOML files within the `<REPO>/constants` directory.

These are usually imported as parsed TOML files, as an argument for a Machine's `configuration.nix` file, in `flake.nix`.

For example, in `control-server`, this is the TOML file with the constants:
```toml
# homelab-constants-values.toml
# A list of defaults to use for any homelab-related machine

default-username = "saphnet-user"
timezone = "America/Los_Angeles"

[networking]
gateway = "192.168.8.1"
nameservers = ["8.8.8.8", "8.8.4.4", "1.1.1.1"]

[email]
address = "homelab@saphnet.xyz"
host = "mail.privateemail.com"
port = "465"
```

This file defines the main username for Instances, the timezone, various networking settings that are shared for systems in the network, and email settings for SMTP.

And this is how the values from the TOML file are imported into the NixOS configuration when listing an Instance in `flake.nix`:
```nix
# In flake.nix:
outputs = {...} @ inputs: let ... in {
  nixosConfigurations = {
    "control-server" = nixpkgs.lib.nixosSystem {
      ...
      modules = [
        (import machines/control-server/configuration.nix {
          ...
          constantsValues = builtins.fromTOML (builtins.readFile "${./constants/homelab-constants-values.toml}"); # The TOML file is read, parsed, and fed directly into the constantValues parameter of configuration.nix
          ... 
        })
      ];
    };
  };
};

# In configuration.nix:
{
  ...
  constantsValues ? throw "Set this to the contents of a constants values file" # This is where constantsValue is taken
}: {...}: let ... in
{
  ...
  networking.nameservers = constantsValues.networking.nameservers; # An example of how constantsValues is used; the Machine's list of nameservers is made into a set of nameservers that are commonly shared among internal Sapphic Homelab machines 
  ...
}
```

Once the TOML file is read and parsed, its contents are passed in as the constantsValues argument, whose attributes are read to define different settings in a Machine's configuration, such as `networking.nameservers` being defined as `constantsValues`'s `networking.nameservers`.

Constants are useful for keeping certain shared values consistent across systems, and for minimizing the work required in instantiating Machines. After Instances, they are the final building block needed for creating NixOS systems.

## Final words
This repository and configuration has various different constructs for easing the creation and deployment of NixOS-based systems for the Sapphic Homelab/Home Server, from Modules to Instances. When put together, we are left with a modular, scalable, and ultimately, powerful system that allows us to harness the power of Nix (the OS, package manager, and language) to deploy a mass of reproducible and reliable systems, virtual and bare-metal, that meet the various needs of the Sapphic Homelab and its users. Hopefully, after reading this guide, you can understand how and why these constructs are created, being simple building blocks for both individual and groups of systems, and can come closer to putting these building blocks together to create something of your own.

Now that you know how and why the repository and its constituent files are structured in the way they are, here is a guide on deploying an actual Instance: [Guide for deploying an Instance](deployment-howto.md)

*An example of an actual machine, with how to instantiate and deploy it*: [control-server](../machines/control-server/README.md)