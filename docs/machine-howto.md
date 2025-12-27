# Guide for creating a Machine

When creating a NixOS-based system to be based on Nix flakes within this repository, the Machine is your main starting point. Analogous to a class in object-oriented programming, the Machine is the blueprint for an actual system, being composed of numerous Modules and other unique functionality/configuration, and is intended to be instantiated to form an Instance: the entity that will be ultimately manifested as a running system. This guide will comprehensively show how to create a Machine from scratch, from its overall structure to the inner workings of its components.

## Machine fundamentals

Each Machine has its own named subdirectory in the `machines` directory, contains all files that the Machine needs access to that don't belong to an Instance, Module, or Constants; most importantly, this subdirectory is home to the central file of the Machine: the `configuration.nix` file. The `configuration.nix` file is ultimately a Nix expression, with a function that describes almost everything about the NixOS configuration; this file, alongside a few other files (e.g. disk and hardware configurations), is what is imported to form a named configuration, in the `flake.nix` file, which can be used by programs like nixos-anywhere for deployment and updating.

Here is a bare-bones example of a `configuration.nix` file:
```nix
{
  modulesPath,
  ...
}:
{
  imports = [
    # NixOS modules
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "25.05";
}
```
At its most basic, this Nix expression consists of a function, which takes in an attribute set with values like `modulesPath` (as well as any other values that may not be named, with `...`) and outputs an attribute set that will form the configuration of a NixOS system. This function is automatically called by the program that deals with NixOS configurations (e.g. nixos-anywhere), and does much of the heavy lifting of determining what is included and what is set to certain values.

The values expressed in the output attribute set include `imports` and `system.stateVersion`. `imports` is an array of Nix expressions (NixOS configuration functions) to import and include with this main NixOS configuration; the imports here include configurations that are needed for a basic system to be able to deployed and run, all of which come from NixOS's internal set of modules (from `modulesPath`). `system.stateVersion` is an attribute that describes the NixOS version that the Machine's configuration values are written for; this is required, as updates for certain software (e.g. PostgreSQL) may bring breaking changes that may lead to incompatibility with existing settings or data. Generally, `system.stateVersion` should just be set to the version of NixOS that you started with for the Machine, and should only be updated after carefully updating configuration values and other application data according to what is described on NixOS's changelogs.

Here is a bare-bones example of how this `configuration.nix` file can be included in the `flake.nix` file when creating an Instance:
```nix
{
  description = "...";
  
  inputs = {
    ...
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    } @ inputs: let
      inherit (self) outputs;
    in {
      nixosConfigurations = { # <- Pay attention, starting here
        "example-server" = nixpkgs.lib.nixosSystem { # The name is defined here
          specialArgs = {inherit inputs outputs;};
          system = "x86_64-linux"; # The system architecture is defined here
          modules = [
            instances/example-server/hardware-configuration.nix # This is the hardware-configuration.nix file for Instances, to be auto-generated on deployment
            (import modules/disko-types/gpt-bios-compat.nix { device = "/dev/sda"; }) # This is the configuration file for Disko, describing the system's disk layout
            machines/example-server/configuration.nix # This is where our configuration.nix file is imported!
          ];
        };
      };
    };
}
```
For the purpose of this guide, we are most interested in the `outputs.nixosConfigurations` attribute: this is an attribute set that matches the names of NixOS configurations (Instances) to the outputs of the `nixpkgs.lib.nixosSystem` function after passing in arguments specific for our example Instance (this output will then be used by tools like nixos-anywhere).

The name of the Instance, or our entry configuration in the nixosConfigrations attribute set, is set to `example-server`; this is what is used in tools (e.g. nixos-anywhere) to refer to this configuration, like with the command `nixos-anywhere --flake <PATH TO CONFIG>#<CONFIG NAME>`, which would be `nixos-anywhere --flake .#example-server` in this example.

`specialArgs`, in this case, is boilerplate that allows the modules imported to use the same inputs and outputs values that are defined earlier in this file.

`system` defines what system architecture is used for this specific configuration (`x86_64-linux` in this case); this generally should be `x86_64-linux`, unless your target system uses another CPU architecture (e.g. ARM or `aarch64-linux`) or another operating system beyond Linux (e.g. macOS or `aarch64-darwin`).

`modules` is an array of Nix expressions (or paths to files with these expressions) that will be imported into thie NixOS configuration:
- `hardware-configuration.nix` is an Instance-specific configuration file that is automatically generated by nixos-anywhere.
- `(import modules/disko-types/gpt-bios-compat.nix { device = "/dev/sda"; })` is our Nix configuration for our disk layout. The Nix expression in the file is actually a curried function (a sequence of functions), where the outer function takes in an argument for the device file that Linux will use (`/dev/sda`, which represents our main hard drive), and then outputs the main function defining our disk configuration that `nixpkgs.lib.nixosSystem` will actually take in as a module.
- `configuration.nix` is our Machine's configuration file from earlier, and will define a large chunk of our Instance's functionality and setup.

Of course, we can define a Machine as a typical function, as described earlier, but this method makes it difficult to add extra arguments/parameters to our main function describing our NixOS configuration (in `configuration.nix`), which is needed to cleanly use a Machine for distinct Instances. To fix this, we wrap this main function in another function (forming a curried function), which takes in Instance-specific values as parameters, and outputs the main function with these values applied, which `nixpkgs.lib.nixosSystem` can use normally.

Here is an example of a `configuration.nix` with this approach applied:
```nix
{ # This is the outer function, which takes in specific parameters
  myHostname ? throw "Please set this to your desired hostname" # An example of a parameter that can be filled
}:
{ # This is the main function taken in by nixpkgs.lib.nixosSystem
  modulesPath,
  ...
}:
{
  imports = [
    # NixOS modules
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = myHostname; # An example of how these parameters can be applied to specific NixOS configuration attributes

  system.stateVersion = "25.05";
}
```
This Nix expression is mostly the same as in our previous example `configuration.nix` file, but there are a few changes. We have the same function from earlier that takes in arguments like `modulesPath`, and outputs an attribute with much of our NixOS configuration, but it is wrapped in another function that takes in another attribute set as a parameter with attributes like `myHostname`. Note that `myHostname` is set to throw (when evaluating this configuration) if it is not set. In order to get a function with a form similar to our previous `configuration.nix` file, we will need to call this outer function with all listed arguments, like `myHostname`, set to any values, which will then return our main (inner) function. This inner function, which can then be used by `nixpkgs.lib.nixosSystem`, will have access to these arguments, and can apply them to any value within its output attribute set. For example, `network.hostName` is set to `myHostname`, which should have been set when calling the outer function with the specified arguments.

This method gives us the power to have multiple Instances that use the same Machine configuration files, but have distinct identities, with unique IP addresses, hostnames, and more. This is also the method that is used to pass in values like the paths to sops-nix secrets files.

Here is how this curried function approach would look like in the `flake.nix` file:
```nix
{
  ...
  outputs =
    {
      ...
    } @ inputs: let
      ...
    in {
      nixosConfigurations = {
        "example-server" = nixpkgs.lib.nixosSystem {
          ... # All extra lines omitted for brevity
          modules = [
            ...
            (import machines/example-server/configuration.nix { myHostname = "example-hostname"; }) # This is where our configuration.nix file is imported!
          ];
        };
      };
    };
}
```
Instead of importing `configuration.nix` as-is, we import it ourselves as a Nix expression (the curried function) to evaluate, and then call the evaluated curried function, with the argument being an attribute set with all of our inner arguments (e.g. `myHostname`) to our desired values (e.g. `example-hostname`). The output of this function call results in the Nix expression (function) that `nixpkgs.lib.nixosSystem` can work with, which is then set as a value of the `modules` array of `nixosConfigurations."example-server"`.

However, typically, the parameters of our curried function usually are in the form of paths to files with Instance-specific values (or Constants), evaluated to Nix expressions (e.g. attribute sets), like in this example `configuration.nix` file:

```nix
{ # This is the outer function, which takes in specific parameters
  instanceValues ? throw "Set this to the contents of your instance's values file" # This parameter should be an attribute set of Instance-specific values, which should be evaluated from an Instance-specific file
}:
{ # This is the main function taken in by nixpkgs.lib.nixosSystem
  modulesPath,
  ...
}:
{
  imports = [
    # NixOS modules
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = instanceValues.myHostname; # We use the value of the myHostname attribute of the `instanceValues` value

  system.stateVersion = "25.05";
}
```

Here's what the `flake.nix` file would look like with the above `configuration.nix` file imported:
```nix
{
  ...
  outputs =
    {
      ...
    } @ inputs: let
      ...
    in {
      nixosConfigurations = {
        "example-server" = nixpkgs.lib.nixosSystem {
          ... # All extra lines omitted for brevity
          modules = [
            ...
            (import machines/example-server/configuration.nix { builtins.fromTOML (builtins.readFile "${./instances/example-server/instance-values.toml}") }) # Our file with Instance-specific values is a TOML file, which is read and parsed into something that the outer function from the above configuration.nix file can take
          ];
        };
      };
    };
}
```

Here's what our `instance-values.toml` file referred to above would look like:
```toml
# instance-values.toml

hostname = "control-server"
```

In essence, in `flake.nix`, when importing the outer function of the `configuration.nix` file, we also read and evaluate the TOML file, `instance-values.toml`, passing the results of this evaluation as the `instanceValues` argument, which gives us our main NixOS configuration function, in which `networking.hostName`, when evaluating this main configuration, will be set to the value of the `myHostname` attribute of the `instanceValues` argument, which was defined in `instance-values.toml`.

Finally, for setting Machine-specific values (but not necessarily Instance or Constants-specific) that are used multiple times in the configuration, or are highly important, you can define extra variables in the let statements section of the main function. Here is an example of a `configuration.nix` with this let statement approach:
```nix
{
  ... # Extra lines omitted for brevity
}:
let
  myHostname = "example-hostname"; # An example of a variable being defined
in
{
  ...
  networking.hostName = myHostname; # An example of how these variables can be applied to specific NixOS configuration attributes
  ...
}
```
In the middle of the input and output sections of this function, `myHostname` is defined as `example-hostname`, which will be the value of `myHostname` in the scope of the function. This variable is then used to defined specific NixOS configuration attributes, like `networking.hostName`. This can be a useful way to quickly define specific constants for a Machine, which can define various values.

The main part of any Machine is its `configuration.nix` file, which is either a function that describes most of a NixOS configuration, which is imported as a module when creating an Instance in the `flake.nix` file, or a curried function that can be called, with arguments consisting of Instance-specific values or evaluated files with those files, to provide the former function. It can be a very complex expression, but there are reasons for adding complexity in specific ways, like this. Now that we have established what a Machine is even made of, we can start to configure it in the next section.

## Basic Machine configuration

The bare-bones Machine that we defined earlier is just enough to be deployed to a virtual machine, but there is not much defined about it, and certainly not enough for it to be useable. This section will cover how to configure a Machine, and what you would need to consider for a typical setup. All of these settings are generally put in the main output section of the Machine's `configuration.nix` file.

**NOTE**: Many of the values defined in these subsections can (and should) be defined by values from let statement variables or outer function parameters (e.g. `instanceValues` or `constantsValues`)!

### Basic user configuration
In order to log into NixOS, you will need to have a user configured to log in with. You can use the root user, but this is strongly recommended against, since this leads to various security issues. Instead, we are going to declare a normal user, with a username, password, list of authorized SSH public keys, and a list of groups it belongs to (which allow various permissions).

Here is an example of a configuration for user functionality:
```nix
users.users = {
  "example-username" = { # This is the name of the username, wrapped in quotes
    password = "example-password"; # This is where the password is defined (NOTE: Use something other than password, like hashedPassword or hashedPasswordFile!)
    isNormalUser = true; # Sets this user to be a normal one, with a home folder and a default shell set
    openssh.authorizedKeys.keys = [ "EXAMPLE SSH PUBLIC KEY" ]; # SSH public keys to accept connections from
    extraGroups = [ "wheel" ]; # Groups the user belongs to, giving various permissions
  };

  root.hashedPassword = "!"; # Disable root login
};
```
This is what each line does in this example, in the `users.users` attribute set:
- `"example-username" = { ... };` - This is the username of the user, in quotes to make sure it is treated as a string; this is an entry in the `users.users` attribute set that corresponds to a specific user.
- `password = "example-password";` - This sets the password of the `example-username` to `example-password`
  - **NOTE**: In a real Machine, do NOT use the `password` attribute! Instead, use `hashedPassword` or `hashedPasswordFile`! The value of `hashedPasswordFile` can be mapped to a sops-nix secret, which will be covered later on in this guide.
  - To generate a hashed password, run `nix run nixpkgs#mkpasswd -- -m sha-512 -s` and type in your password. The resulting output will be a corresponding hashed password.
- `isNormalUser = true;` - This sets this user as a normal user, as opposed to a system user. This ensures that the user is added to the `users` group, that the user has a home folder associated to it, and that it can use a shell (e.g. Bash).
- `openssh.authorizedKeys.keys = [ "EXAMPLE SSH PUBLIC KEY" ];` - This sets the list of the user's authorized SSH public keys (public keys that identify an outside party connecting); this attribute takes in arrays of strings. Note that public keys are generally safe to leave in the open in plaintext, given that the private key is secret.
- `extraGroups = [ "wheel" ];` - This sets the list of groups that the user is part of this; this attribute takes in an array of strings. These groups are what allow a user to have certain permissions (e.g. `docker` for accessing Docker). In this case, we are adding our user to the `wheel` group, which enables for access to the `sudo` command, for running commands as root.
- `root.hashedPassword = "!";` - This sets the root user's hashed password to `!`; this value is impossible for any password to evaluate to, essentially disabling access to the root user.

You are welcome to add even more users, or have no users, depending on the needs of the Machine. You are also welcome to use Home Manager, but for most server-related needs, the configuration above suffices.

### Basic networking

> NOTE: This is where you set your hostname for your Machine/Instance! Again, the values of these settings are recommended to be set in your file(s) for Instance-specific values and/or Constants-specific values. 

NixOS can handle networking functionality on its own, assuming that the network that an interface is connected to has a DHCP server, but you most likely want to have a pre-set IP address, hostname, and other networking settings, so that any services sit upon a predictable location.

Here is an example of a configuration for networking functionality:
```nix
networking.hostName = "example-hostname";
networking.domain = "example.com";
networking.defaultGateway = "192.168.0.1";
networking.nameservers = [ "8.8.8.8", "8.8.4.4" ];
networking.interfaces."ens18" = {
  useDHCP = false;
  ipv4.addresses = [
    {
      address = 192.168.0.2;
      prefixLength = 23;
    }
  ];
};
```
This is what each line does in this example, in the various parts of the `networking` attribute:
- `networking.hostName = "example-hostname";` - This sets the system's hostname to `example-hostname`. This then gets combined with the value of `networking.domain` to form the Fully Qualified Domain Name (FQDN).
- `networking.domain = "example.com";` - This sets the system's domain to `example.com`. Combined with the value of `networking.hostName`, the FQDN becomes `example-hostname.example.com`. This attribute is highly optional, but in a server setting, is recommended to set to something real.
- `networking.defaultGateway = "192.168.0.1";` - This sets the default gateway of the system (the IP address/interface that connects to another network, usually the wider Internet) to `192.168.0.1`.
- `networking.nameservers = [ ... ];` - This sets the default nameservers for the system to use. In our example, we use the IP addresses for Google DNS: `8.8.8.8` and `8.8.8.4.4`.
- `networking.interfaces."ens18" = { ... };` - This is the name of the networking interface we are configuring (`ens18`), wrapped in quotes to ensure the name is treated as a string. In this case, we use `ens18` as that is the default interface name for a Proxmox virtual machine; the name of the interface is HIGHLY hardware/hypervisor-dependent. Note that you can define multiple interfaces, by defining `networking.interfaces` as an attribute set mapping the names of different interfaces to their corresponding settings. 
- `useDHCP = false;` - Disables DHCP for the `ens18` interface, as we plan to use a static IP for this system.
- `ipv4.addresses = [ ... ];` - This configures the list of IP addresses that the `ens18` interface uses; this is an array of attribute sets (mapping to IP addresses).
- `address = 192.168.0.2;` - This sets an IP address for the `ens18` interface: `192.168.0.2`.
- `prefixLength = 23;` - This sets the length of the prefix for the aforementioned IP address. Combined with the previous address, we would get a prefix of `192.168.0.0/23`.

Remember that these networking settings are HIGHLY network-dependent, and hardware/hypervisor-dependent! You are welcome to use as many or as little networking settings as you wish. Also, I recommend that your FQDN is mapped (via DNS) to the actual IP address that your system will use.

### Miscellaneous settings

Here are some other settings that you might want to set (again, feel free to set these to values that are defined in Instance-specific or Constants-specific files):
- `time.timeZone = "EXAMPLE/TIMEZONE";` - Sets the timezone of the system to the one specified, as a [tz database timezone name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

### NixOS packages

Alongside your Machine's other configuration settings, you are also able to include Nix packages in the system's environment, that users can use and access by default, without having to download or install anything extra; for example, you can use this to download different kinds of tools, such as `vim` and `ncdu`. Note that this is different to enabling services with NixOS, which automatically deal with the packages that are needed for such services to work.

Here is an example of a list of packages that can be included in a Machine's configuration:
```nix
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
```
This sets `environment.systemPackages` to be a list of packages; `with pkgs` allows these names to resolve to the Nix expressions (part of `pkgs`) that map to the actual packages that they refer to.

Note that the versions of the packages installed highly depends on the version of NixOS specified in `nixpkgs` in `inputs` in the `flake.nix` files:
```nix
{
  ...
  
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05"; # This is the repository where the version of NixOS is set, which determines the version of the packages that are installed
    ...
  };

  outputs = { ... };
}
```
`nixpkgs.url` sets the URL of `nixpkgs` to that of the GitHub repository for NixOS version 25.05. Updating this URL changes the versions of packages that are installed.

Beyond the version of nixpkgs, the specific versions/checksums of packages that are installed are pinned in the `flake.lock` file.

### Considering disk configuration, with Disko

Even though the disk configuration module being used will be specified when defining an Instance in the `flake.nix` file, you will still need to consider your disk configuration when defining your Machine's functionality: your disk configuration can have you use more than one disk, have various directories mounted in novel ways or to novel locations (particularly when using Impermanence), or use unique filesystems or disk management methods (e.g. LVM). Be sure to have a look at `modules/disko-types` to see whether any configurations meet your needs.

### version-lock.toml

Another indispensable file in the creation and maintenance of any Machine is the `version-lock.toml` file. In essence, it is a TOML file that prescribes the versions of various components and settings of your Machine, including `system.stateVersion`, and the version of Docker images outside of Docker Compose files; it does the job of the `flake.lock` file for non-flake software and settings. It is specific to the Machine (or Module), not the Instance, and allows us to pin things to specific versions for the sake of reproducibility (mostly, at least, in this form, without using checksums).

> NOTE: If using Docker Compose, simply specify the container image versions in your `compose.yaml` files, rather than in the `version-lock.toml` files! This allows Dependabot to easily check on these files and propose updates automatically; to enable Dependabot for your `compose.yaml` files, make sure to add the directory containing those files to the `directories` list in `updates` in `.github/dependabot.yml`.

The `version-lock.toml` generally sits in the same subdirectory as the `configuration.nix` file; that is, it sits in the Machine's own subdirectory.

Here is an example of a `version-lock.toml` file:
```toml
# version-lock.toml

state-version = "25.05"

[example-program]
program-version = "v1.0.0"
```

This is how the `version-lock.toml` file from above is used in a Machine's `configuration.nix` file:
```nix
{
  lib,
  pkgs,
  ... # Extra lines omitted for brevity
}:
let
  versionLock = lib.importTOML ./version-lock.toml; # version-lock.toml is read and parsed, and its values are fed into the versionLock variable
in
{
  ...
  # This example service just spins up a Docker container with a specific image, with the specific version
  systemd.services."example-service" = {
    ...
    script = with pkgs; ''
      ${pkgs.docker}/bin/docker run example-image:${versionLock.state-version.program-version} # The version of the image, from version-lock.yaml
    '';
  };
  
  system.stateVersion = "${versionLock.state-version}";
}
```
The `version-lock.toml` pins the `configuration.nix` file's `system.stateVersion` to `25.05`, and the version of the Docker image (`example-program.prorgam-version`) to `v1.0.0`.

This is what each (relevant) line does in this example, in the `users.users` attribute set:
- `versionLock = lib.importTOML ./version-lock.toml;` - In the let statements section, the `version-lock.toml` file, in the same directory as the `configuration.nix` file itself, is imported and parsed, and `versionLock` is set to the contents of the `version-lock.toml` file.
- `${pkgs.docker}/bin/docker run example-image:${versionLock.state-version.program-version}` - This is the script of the `example-service` service, which starts a Docker container, with the `example-image` image, with the version of this image being set to the version set in `versionLock.state-version.prorgam-version`, which is `v1.0.0`.
- `system.stateVersion = "${versionLock.state-version}";` - This sets `system.stateVersion` to the `state-version` value set in the `version-lock.toml` file, being `25.05`.

With many of the core settings of your Machine's configuration specified, we are getting closer to a complete Machine that we can use to create Instances with. In the next section, we will cover adding major functionality with Modules and Machine-specific features/files, as well as advanced considerations, particularly in terms of secrets management and dealing with persistence.

## Adding numerous features

With your Machine's main settings now set, you should be able to have something that you can log into and use, but there still isn't much in terms of functionality or services that make the Machine useful; as well, you might want to consider storing your secrets (e.g. passwords) with sops-nix, and configure Impermanence to keep your system clean between reboots. This last section of the guide will cover adding the remaining such functionality to a Machine.

### Importing Modules

*More on how to create a Module*: [Guide for creating a Module](module-howto.md)

The main way of adding functionality to a Machine is by importing a Module, which is a basic, reusable block of functionality, expressed as a portion of a NixOS configuration. There are numerous kinds of Modules, ranging from those that add basic functionality for a system (e.g. for Proxmox virtual machines), to those that add unique features, such as Tailscale or Docker support.

To import a Module in a Machine, add the path to the Module, in the `modules` attribute in the `configuration.nix` file:
```nix
{
  ...
}:
{
  imports = [
    # NixOS modules
    ... # Extra lines omitted for brevity
    # Internal modules
    ...
    (../.. + "/modules/virtualization/docker.nix") # An example of a Module being imported
    ...
  ];
}
```
A path to a Nix configuration file that represents a Module (in this case, for basic Docker functionality) is added to `imports`, which is an array of Nix files to import and evaluate; the contents of their Nix expressions get merged with the rest of the main NixOS configuration. The path here is created by combining `(../..)` (which results in the root directory of the repository by moving to the parent directory twice), with `/modules/virtualization/docker.nix` (the relative path from the repository root), to get the absolute path of the `docker.nix` file to import.

Some Modules might consist of curried functions (with two layers) that require being called with various arguments set in order to get the main NixOS configuration function. For example, here's how an example Module, made of a curried function, would be imported into the `configuration.nix` file:
```nix
{
  ...
}:
{
  imports = [
    # NixOS modules
    ... # Extra lines omitted for brevity
    # Internal modules
    ...
    (import (../.. + "/modules/example/example.nix") { exampleVar = "example"; } ) # An example of a (curried function) Module being imported
    ...
  ];
}
```
This creates the absolute path to the example module, which then gets imported and evaluated as a Nix expression, then get called as a function, with an attribute set, with `exampleVar`, as the argument, which outputs the main part of the Module (the main function), which will serve as an element of the `imports` array, to be evaluated later by `nixpkgs.lib.nixosSystem`.

Note that some Modules may not be curried functions, but still expect a certain input to be accessible (passed in as an input to the `configuration.nix` file), like the sops-nix Module expecting the `secretsFile` input. Before importing any Module, make sure to check its file for any special instructions.

### Impermanence

[Impermanence](https://github.com/nix-community/impermanence) is a community-made NixOS module that allows you to pick files and directories to keep while making sure any other files are thrown away between reboots. This allows for ensuring that an installed system remains clean without previous state to consider, reinforces the importance of explicitly declaring settings to keep, and allows for experimentation without leftover clutter; in short, it is a way to force good NixOS habits while keeping a clean system.

This repository includes an internal Module for including Impermanence in a Machine; it assumes that you have an entry for it (with a URL) in `inputs` in `flake.nix`. However, there are numerous considerations that need to be made when including this Module in your Machine, as it assumes a specific way of how your system is structured, all of which we will cover here.

Before including Impermanence in a Machine, you will need to make sure you write your Machine for a disk configuration that is designed to work with Impermanence, as Impermanence needs to work with the filesystem to write non-persistent files to locations that will eventually be erased, while keeping persistent files in a safe location. For example, a disk configuration type that will work for most systems is `modules/disko-types/impermanence-btrfs.nix`, which implements the storing of non-persistent data with BTRFS subvolumes, which will be automatically erased on boot. 

> NOTE: `/persist` is only a suggested location for storing permanent files! You can have the location be any direction, as long as Impermanence is configured to look there, and that your disk configuration is also configured to store persistent files there (e.g. in an LVM volume named after the same location). 

Generally, for most systems, all persistent files will be stored in `/persist`, in subdirectories that are relative to where they will be in the root directory (`/`); at boot time, all inside directories and files will be mounted to their location, relative to the root directory (instead of just `/persist`). If you have services or other needs that rely on files that need to persist between reboots, make sure that their locations are stated in the list of locations to stay persistent, or if the service has to run before Impermanence runs, then that any of their references to persistent files are relative to `/persist` instead of the root directory.

For example, `/etc/machine-id`, a file that commonly needs to be set as persistent, needs to be listed in the list of directories to stay persistent. This means that it will be permanently stored at `/persist/etc/machine-id`, and then mounted to `/etc/machine-id` once Impermanence is running.

To include Impermanence functionality in your Machine, add the Module (`modules/impermanence-types/default.nix` will work for most machines) to `modules` in the `configuration.nix` file:
```nix
{
  ...
}:
{
  imports = [
    # NixOS modules
    ... # Lines omitted for brevity
    # Internal modules
    ...
    (../.. + "/modules/impermanence-types/default.nix") # Simple import here
    ...
  ];
}
```

This default configuration for Impermanence includes the bare basic files and directories to include as persistent (e.g. `/etc/machine-id`), a script to run on boot-up to erase previous subvolumes with non-persistent data, and other settings. If you're not adding any extra functionality, you will not need to add any more configurations or settings.

However, if you are adding extra functionality, like Docker or Tailscale, you will need to add another list of directories and files to set as part of the persistent directory, under `environment.persistence."/persist"` (again, `/persist` can be any other location that you set), as part of either the `directories` or `files` arrays. This will be merged with the list of directories and files marked as persistent in the internal Impermanence Module.

For example, here is how the Machine, `control-server`, handles adding persistent files:
```nix
environment.persistence."/persist" = { # Additional files to base ones
  directories = [
    "/var/lib/docker/" # Docker
    "/etc/komodo" # Komodo
  ];
  files = [
    "/var/lib/tailscale/tailscaled.state" # Tailscale
    "/var/lib/reverse-proxy-bootstrap-complete" # For initial SSL cert bootstrapping
  ];
};
```
This configuration adds the directories `/var/lib/docker` and `/etc/komodo` to the `directories` array, which means that they will be saved in `/persist`; the same goes for the two files under `files`.

Generally, a Module will tell you what files need to be persistent, so that you can add them to this list. As well, when adding your own functionality, particularly with Docker Compose, make sure to pay attention to the paths and volumes that are used and mounted that will need to be persistent between reboots. With Docker volumes, make sure that you set `/var/lib/docker/` as persistent (you can also be more specific and specify `/var/lib/docker/volumes`).

Assuming everything is correctly set according to this guide, Impermanence should now be set up within the Machine. Still, be careful to include any necessary files or directories within the persistence list, and that your Impermanence and disk configuration settings line up properly.

### sops-nix

[sops-nix](https://github.com/Mic92/sops-nix) is a community-made NixOS modules for secrets management, using [sops](https://github.com/getsops/sops). It allows you to have any secrets created with sops declaratively be accessible to NixOS and any services listed in the its configuration, as the locations of the secrets will be generated upon flake evaluation; sops-nix will only decrypt these secrets to be accessible at these locations upon startup. This can be very useful for storing values, such as passwords, passphrases, and tokens, securely, while still having them easily integrate with the Nix/NixOS ecosystem; these secrets, assuming that they are encrypted with the private key being secret, can be stored in the open alongside the rest of a NixOS configuration.

This repository includes an internal Module for sops-nix functionality. To import this in your machine, make sure that you have an input value named `secretsFile`, which is set to the path of your sops secrets file (it can be as a parameter in the outer layer of a curried function), and then add the file for the Module (`/modules/sops-nix-types/default.nix`) in the `imports` array of your `configuration.nix` file, with the `inputs` and `secretsFile` input values inherited:
```nix
{ # Custom args
  secretsFile ? throw "Set this to the path of your instance's secrets file", # The secretsFile input is taken from here
  ...
}:
{
  ...
}:
let
  ...
in
{
  imports = [
    # NixOS modules
    ...
    # Internal modules
    ...
    (import (../.. + "/modules/sops-nix-types/default.nix") {
      inherit inputs secretsFile;
    }) # This imports the file for the Module, evaluates the expression inside it, and calls it while inheriting inputs and secretsFile; the output is then set as an element of the imports array
    ...
  ];
}
```
This example configuration consists of a curried function, where the outer layer takes in an argument for `secretsFile`, which our sops-nix Module will then be able to take in as an input. When adding the sops-nix Module to the `imports` array, we do it by importing the file for the Module, and calling it with the `inputs` and `secretsFile` input values inherited from our current function. The output of this function call then become an element of the `imports` array.

Most of the configuration of sops-nix secrets is in the Instance-creation stage, but there are still some settings that we need to consider when creating a Machine. (Do note that these secrets will only be accessible if we pass the right age key for decrypting them, in `/var/lib/sops-nix/keys.txt`)

Most importantly, we still need to declare these secrets in our `configuration.nix` file, with their names and any other settings configured, in order for them to be usable when the NixOS configuration is evaluated at build-time. Here is an example of these secrets being declared for the Machine, `docker-host`:
```nix
sops = { # Secrets are stored in sops.secrets
  secrets = {
    main-password-hashed = {
      neededForUsers = true; # Setting so that password works properly
    };
    komodo-passkey = {};
  };
};
```
In this example, both secrets are names of secrets mapped to attribute sets with any extra settings (they are usually empty sets, however). Note that `main-password-hashed`, which is the secret for the hashed password of a user account, has the setting `neededForUsers` set as true: this needs to be set, so that the hashed password is available at the stage in system startup where users are set up, because sops-nix has its own stage where it decrypts and writes secrets. 

With our sops-nix secrets now set, we can now use them in the rest of our NixOS configuration. The way sops-nix works is that we have to access individual secrets through their paths: if we have a secret named `example-secret`, we just refer to it through `config.sops.secrets.example-secret.path`. When these secrets are needed, These files in these paths will then be read at run-time in a running system. Here's an example of how this is used to set the hashed password, for the Machine, `control-server`:
```nix
users.users = {
  "${constantsValues.default-username}" = {
    hashedPasswordFile = config.sops.secrets.main-password-hashed.path; # Since hashedPasswordFile just expects a path to a password file, and sops-nix works by giving out paths (which can only be read to get secrets when the system is actually running), we can just give the path here
    ...
  };
  ...
};
```
The setting for hashedPasswordFile, which asks for a path to a file, is set to `config.sops.secrets.main-password-hashed.path`; this refers to the secret `main-password-hashed`, and will be evaluated as an automatically generated path to this secret that will be valid when the system is running. Again, remember that for password-related settings like these, we need to make sure these secrets are marked as necessary for loading things like files, as mentioned in the `neededForUsers` setting earlier.

However, not all services ask for paths to secrets; instead, particularly for Docker Compose setups, many services ask for the secrets themselves, outright, as environment variables. Since sops-nix secrets themselves are not available when our NixOS configuration is being evaluated, instead only being available at run-time, we have to configure our services to set and export an environment variable to the value of the secrets file at the path, right before being run, like in this example from the Machine, `control-server`:
```nix
systemd.services."komodo-control" = {
  ...
  environment = {
    ... # If a secrets environment variable wants a path to a file, instead of the secret inself, we can just declare it here, otherwise we need to export the variable in the script section
  };

  script = with pkgs; ''
    ...
    # Dynamically export variables from secrets files, reading them at run-time
    export KOMODO_DB_PASSWORD=$(cat ${config.sops.secrets.komodo-db-pass.path})
    export KOMODO_PASSKEY=$(cat ${config.sops.secrets.komodo-passkey.path})

    ${pkgs.docker}/bin/docker compose -p komodo -f ${./komodo-control/mongo.compose.yaml} --env-file ${./komodo-control/compose.env} up
  '';
};
```
In this example, in the script section of the service, which is run when the system itself is running, we run the `cat` command with the path of the secret (from `configs.sops.secrets.<SECRET_NAME>.path`), and the output of this command is read into the environment variables (which are exported) for the secrets that our Docker Compose file is looking for. This allows for us to pass secrets themselves into services and programs, instead of just their paths.

#### IMPORTANT: If using Impermanence with sops-nix

> **NOTE**: If you are using Impermanence **and** sops-nix, failing to follow these instructions will result in sops-nix secrets being inaccessible to the services and programs that require them!

If you're using the sops-nix Module **with** the Impermanence Module, you will need to follow a special set of steps, different to what was described in the previous instructions for sops-nix, in order for both sops-nix and Impermanence to properly work together.

When importing the sops-nix Module alongside the Impermanence Module, instead of using the `modules/sops-nix-types/default.nix` file, use the `modules/sops-nix-types/default-impermanence.nix` file, which is a variety designed to work with Impermanence.

Still, you will need to import it in the same way as previously described, with it having access to both the `inputs` input and the `secretsFile` input (the path to the secrets file, which can be passed in as a parameter to the outer function of a curried function). Here is how it is imported in the Machine, `control-server`:
```nix
{ # Custom args
  secretsFile ? throw "Set this to the path of your instance's secrets file", # Still, the secretsFile input is taken from here
  ...
}:
{
  ...
}:
let
  ...
in
{
  imports = [
    # NixOS modules
    ...
    # Internal modules
    ...
    (import (../.. + "/modules/sops-nix-types/default-impermanence.nix") {
      inherit inputs secretsFile;
    }) # Note that we are using default-impermanence.nix, not default.nix! Everything else about importing it still goes as usual 
    ...
  ];
}
```

Once the specific variety of this Module, being the `default-impermanence.nix` file, is imported, we will not need to worry about doing any other tasks until we start with the Instance-creation stage, as this variety of the Module handles storing necessary files for decrypting secrets, such as `/var/lib/sops/keys.txt` and SSH hosts key, in the persistent directory (e.g. `/persist`). Still, do remember that these files are more reliably available during startup in their location within the persistent directory (e.g. `/persist`), rather than in their location within the root directory.

### Features based on Docker Compose 

Many services or pieces of functionality may be based on Docker containers and volumes, as defined with a Docker Compose file; this allows for easy portability to non-NixOS systems, access to software with better availability in Docker than in NixOS, and, importantly, the ability to easily host services within containers. For example, the Komodo functionality in the Machines, `control-server` and `docker-host`, is mostly defined with Docker Compose files. These Docker Compose files are usually in a subdirectory under the directory dedicated for a Machin. This approach allows for many possibilities, but there are numerous considerations and limitations imposed by having our Docker Compose files (and other files they rely on) being distributed with our NixOS flake, which we will cover in this section. 

Here is an example `compose.yaml` file for an example service with Docker Compose (let's say that it's stored as `machines/example-server/hello-world/compose.yaml`):
```yaml
services:
  hello_world:
    image: hello-world
```
This is a very simple Docker Compose file, which consists of a single container (or Docker Compose service) that uses the `hello-world` image.

To have this Docker Compose file be automatically started by NixOS on startup, we create a systemd service, in our `configuration.nix` file, that runs `docker compose up` on our `compose.yml` file:
```nix
systemd.services."hello-world" = {
  description = "Start hello-world";

  wantedBy = ["multi-user.target"];
  wants = ["network-online.target"];
  after = [
    "docker.service" # Docker needed, of course
    "docker.socket"
    "network-online.target" # Need working internet to get things
  ];

  script = with pkgs; ''
    # Waiting for the network to actually come online
    sleep 5

    ${pkgs.docker}/bin/docker compose -p hello-world -f ${./hello-world/compose.yaml} up
  '';
};
```
This is what each line does in our example:
- `systemd.services."hello-world"` - This declares our systemd service, with the name `hello-world` (in quotes to ensure it is processed as a string).
- `description = "Start hello-world";` - This is a simple description of our systemd service. This will be shown on startup and shutdown as the service is started and stopped.
- `wantedBy = ["multi-user.target"];` - This makes this service wanted by `multi-user.target`, which effectively makes this service start after we reach a certain point in the boot process.
- `after = [ ... ];` - These are certain targets and services that we want to wait for and have start first before we start this service.
  - `"docker.service"` - This has us wait for the Docker daemon to start first.
  - `"docker.socket"` - This has us wait for the Docker socket to start first. (This is to be extra safe)
  - `"network-online.target"` - This has us wait for the network to be online and accessible before starting, as we need the Internet in order to download the necessary Docker images. We also have this in our `wants` section to be extra sure the network is online when starting. Note that this does not guarantee that the Internet is in working order when the systemd service starts, which we will handle in the `script` section.
- `script = with pkgs; '' ... ''` - This is the shell script (as a multi-line string) that the systemd service runs when it is started. We use `with pkgs` so that we can easily access the paths to NixOS packages (e.g. Docker) when evaluating the final contents of the script.
  - `sleep 5` - Since the Internet may not be in working order when the systemd service is started, we wait for 5 seconds before continuing (this is generally a sufficient amount of time to wait).
  - `${pkgs.docker}/bin/docker compose -p hello-world -f ${./hello-world/compose.yaml} up` - This command actually starts the Docker Compose file (with `docker compose up`). Note that we refer to `pkgs.docker` here, which will automatically resolve to the path of the Docker package in the Nix store during the evaluation stage with our NixOS configuration; furthermore, this location is just a directory, so we have to specify `/bin/docker` in order to use the Docker binary. We set our project name (`-p`) as `hello-world`. The file here being used as the Docker Compose file is our `compose.yml` file from earlier, which is being referred to by its relative location to the `configuration.nix` file; this will be automatically resolved to its path in the Nix store during the evaluation stage with our NixOS configuration.

Of course, we want to do more than just run hello-world: we also want to mount files and volumes for our Docker containers to work with. When it comes to local data that isn't shipped with the Nix flake repository, we just do the usual procedure for Docker Compose files (and if using Impermanence, ensuring their locations are saved as persistent).

However, when it comes to non-Nix configuration files shipped with our Nix flake repository, our options are more limited: we cannot just refer to these files with relative paths in our Docker Compose files, as each file is stored as its own file in its own directory, in a flat structure in the Nix store. Instead, we have to set the paths of each non-Nix configuration file as environment variables that the Docker Compose file will then read and use as paths to mount within its Docker containers; these environment variables will be expressed as Nix relative paths which will be replaced with their absolute paths within the Nix store during the evaluation stage with our NixOS configuration. 

Unfortunately, this means that we cannot import directories wholesale into our Docker Compose setups; instead, we will have to do so when later creating Docker Compose setups within Komodo, and try to do as little as possible in our flake configuration in order to support extra Docker Compose setups. 

Here is an example of how this problem is handled for the `reverse-proxy` service in the Machine, `control-server`, in its `configuration.nix` file:
```nix
systemd.services."reverse-proxy" = {
  ... # Lines omitted for brevity
  environment = { # These files will be stored in the Nix store, so we store their locations as environment variables, which Docker Compose will automatically resolve, with their paths being mounted to the right locations in 
    NGINX_CONF_FILE = "${./reverse-proxy/nginx.conf}";
    NGINX_PROXIES_FILE = "${./reverse-proxy/proxies.conf}";
    NGINX_CONFD_BLOCK_EXPLOITS_FILE = "${./reverse-proxy/nginx-conf.d/block-exploits.conf}";
    NGINX_CONFD_PROXY_FILE = "${./reverse-proxy/nginx-conf.d/proxy.conf}";
    NGINX_CONFD_SSL_FILE = "${./reverse-proxy/nginx-conf.d/ssl.conf}";
    NGINX_CONFD_IP_RANGES_FILE = "${./reverse-proxy/nginx-conf.d/ip-ranges.conf}";
    NGINX_AUTORELOAD_FILE = "${./reverse-proxy/99-autoreload.sh}";
    ...
  };

  script = with pkgs; ''
    ...
    ${pkgs.docker}/bin/docker compose -p reverse-proxy -f ${./reverse-proxy/compose.yaml} up
  '';
};
```
As well, here is how it looks like in its `reverse-proxy/compose.yaml` file:
```yaml
... # Lines omitted for brevity
services:
  nginx:
    image: nginx:1.29.3
    ... # Lines omitted for brevity
    volumes:
      # Main conf file
      - ${NGINX_CONF_FILE}:/etc/nginx/nginx.conf:ro
      - ${NGINX_PROXIES_FILE}:/etc/nginx/proxies.conf:ro
      # conf.d files
      - ${NGINX_CONFD_BLOCK_EXPLOITS_FILE}:/etc/nginx/conf.d/block-exploits.conf:ro
      - ${NGINX_CONFD_PROXY_FILE}:/etc/nginx/conf.d/proxy.conf:ro
      - ${NGINX_CONFD_SSL_FILE}:/etc/nginx/conf.d/ssl.conf:ro
      - ${NGINX_CONFD_IP_RANGES_FILE}:/etc/nginx/conf.d/ip-ranges.conf:ro
      ...
      # Script to autoreload Nginx when certs are renewed
      - ${NGINX_AUTORELOAD_FILE}:/docker-entrypoint.d/99-autoreload.sh:ro
    ...
...
```
In the systemd service's `environment` section, various environment variables are set to `"${./reverse-proxy/<EXAMPLE_FILE>}"`: what is expressed is the path to the file, relatively to `configuration.nix`, which will automatically be resolved to their absolute locations in the Nix store during the evaluation stage with our NixOS configuration. These environment variables are accessible to the process starting up our Docker Compose service, which will then pass these variables in, mounting the paths described these variables as their specified locations within our Docker Compose files.

Finally, you might want to import sops-nix secrets into your Docker Compose services. To do so, assuming that your secret is defined in the list of sops-nix secrets, we can either just set an environment variable to the path of the secret, if the environment variable is just for the path, or dynamically read the contents of the path of the secret into an environment variable at run-time, otherwise. Here is an example with an example service in an example `configuration.nix` file:
```nix
systemd.services."example-service" = {
  ... # Lines omitted for brevity
  environment = {
    SECRET_1_FILE = "${config.sops.secrets.secret1.path}";
    ...
  };

  script = with pkgs; ''
    export SECRET_2=$(cat ${config.sops.secrets.secret2.path})

    ${pkgs.docker}/bin/docker compose -f ${./example-service/compose.yaml} up
  '';
};
```
This is what the example `compose.yaml` file would look like:
```yaml
services:
  example-service:
    image: example-image
    environment:
      SECRET_1_FILE: ${SECRET_1_FILE} 
      SECRET_2: ${SECRET_2} 
```
In this example, our example-service requests two secrets: `SECRET_1`, which it will take by reading the file listed in the `SECRET_1_FILE` environment variable, and `SECRET_2`, which is just the contents of the secret itself. It can declare the contents of `SECRET_1_FILE` in the `environment` section of the systemd service, as its location, `config.sops.secrets.secret1.path`, is known in advance. For `SECRET_2`, we have to have our script read the contents of the path that `config.sops.secrets.secret2.path` resolves to and then save it to an environment variable. The `docker compose up` command will then resolve the values of these environment variables and pass them to the environment of the `example-service` container, which can then do something useful with them.

With every single way to add functionality to a Machine being covered, from importing Modules to creating custom Docker Compose setups, we are now able to do anything with a Machine and have it serve many purposes; we are also able to leverage the powers of Impermanence and sops-nix to make our NixOS configurations more powerful, clean, and declarative. We have also covered all the considerations, choices, and pitfalls of the various options we have for adding functionality to our Machine, as well as how to work with them. With the Machine complete, we can finish up this stage in the process of creating NixOS systems in this repository.

## Final words

The Machine is the central point of creating any NixOS system in the scope of this repository: it is the blueprint for any Instance, and is where the vast majority of a NixOS system's functionality and purpose is defined. There are an incredible amount of factors involved in the creation of a Machine, in terms of how it is structured, what it is made of, and how its constituent parts interact with each other, but, hopefully, this guide has shown you, in a logical progression, how to approach each step, and finally come up with a complete Machine. Now that we have a Machine defined, we are left with only one thing to define before finally creating a NixOS system: the Instance.

With a Machine now created, here is a guide on creating an Instance with this new configuration: [Guide for creating an Instance](instance-howto.md)