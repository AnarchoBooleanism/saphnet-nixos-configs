# Machine: `control-server`
This machine is made for use as a control server for both Komodo and Ansible (as a Proxmox VM within the Sapphic Homelab).

As part of the deployment bootstrapping process, after Proxmox is deployed to the bare-metal hosts, `control-server` is the machine first deployed to the Sapphic Homelab, directly from another personal computer through nixos-anywhere (and indirectly through Ansible), before other machines can be deployed with Ansible and/or nixos-anywhere.

Because `control-server` is the most important out of all the machines in this configuration, this document is a complete guide on how to set it up and maintain it, from creating secrets and instance values, to using nixos-anywhere and updating it.

## Quick explanation
`control-server` has a few central services (via systemd and Docker Compose) that it serves: a Komodo control server, an Ansible control server (through Semaphore UI), and a reverse proxy, using Nginx. Many of the Docker containers listed communicate with each other through a Docker network, named `central-network`. This server should also be accessible over Tailscale.

### systemd.services."central-network"
This is a oneshot service whose goal is, on startup, check whether a Docker network named `central-network` exists. If it does not, then it creates the network, then exits. All of the containers/services that rely on `central-network` have to wait for this service to complete running before they can start, as they have a dependency on the network, which is external to all of them.

### systemd.services."komodo-control"
This is a service that starts the Docker Compose configuration for the Komodo control server, which manages Docker containers and Docker Compose stacks across multiple machines that have Komodo Periphery installed. It has to wait for `central-network` to be created before starting. As well, various secrets are passed in from sops-nix secrets files, into environmental variables, which then get passed into the relevant containers. Komodo stores its data in `/etc/komodo`, which will need to be backed up by some other service, most likely [docker-volume-rclone](https://github.com/AnarchoBooleanism/docker-volume-rclone).

### systemd.services."ansible-control"
This is a service that starts the Docker Compose configuration for the Ansible control server, i.e. Semaphore UI, which manages the deployment of all machines in the Sapphic Homelab network, particularly for those not running NixOS. It has to wait for `central-network` to be created before starting. As well, various secrets are passed in from sops-nix secrets files, into environmental variables, which then get passed into the relevant containers. Ansible stores its data in Docker volumes, and particularly in the form of SQL databases; these can easily be backed up using [docker-volume-rclone](https://github.com/AnarchoBooleanism/docker-volume-rclone).

### systemd.services."reverse-proxy-bootstrap"
This is a service that uses Certbot (more specifically, an image of Certbot that has a plugin for DNS challenges with Namecheap), to create SSL certificates for `reverse-proxy` (as well as the Docker volume that stores these certificates, `certbot-conf`). `reverse-proxy` has a hard dependency on this service, as Nginx will not work without having SSL certificates configured first. It does rely on sops-nix secrets and other instance values to do its jobs correctl. This is supposed to be a one-time process, done at first boot; this is achieved by checking for the existence of a certain file that will only exist if this service has fully completed running previously, in which case, the service completes early, allowing for `reverse-proxy` to start.

### systemd.services."reverse-proxy"
This is a service that starts the Docker Compose configuration for reverse proxy for the other services listed above; the configuration uses Nginx, as well as Certbot, for automating certificate renewals. Its main goal is to enable connections to the listed services securely through HTTPS, as well as through a convenient domain name. It has to wait for `reverse-proxy-bootstrap` to complete first before it can start. As well, it has to wait for `central-network` to be created before starting, as this network is used to directly connect to other containers. In this configuration, Nginx relies on multiple .conf files, with different purposes, that are directly passed in through environment variables, and mounted according to those environment variables. Again, this does rely on sops-nix secrets and various other instance values to do its job correctly. This service also uses the `certbot-conf` volume for accessing and renewing SSL certificates, which should have been created first by `reverse-proxy-bootstrap`.

## Steps to instantiate `control-server`
These instructions are oriented for non-NixOS systems that have Nix installed, with flakes and nix-commands enabled.

You will want to put any files with instance-related values in a directory within `<REPO>/instances/`. For example, in this guide, we use `<REPO>/instances/control-server`.

### 0. Create (or delegate) an SSH key for communication with `control-server`
Make sure to create an SSH key (or repurpose one that you already have). This will be the one that you feed to [the NixOS installer](https://github.com/AnarchoBooleanism/nixos-cloud-init-installer) via cloud-init, allowing for secure access; likewise, the SSH key will be passed to `nixos-anywhere` during the installation process. This will also be the key that you use to access `control-server`, once it is installed. (You are welcome to use passphrases here)

To create an SSH key, you can simply run `ssh-keygen -t ed25519 -C "PCUSERNAME@PCHOSTNAME"` (this should be with the details of the PC that you are using to connect to `control-server`)

Make sure to take note of the public keys generated here, as these will be passed into your `instance-values.toml` file.

### 1. Generate SSH keys for use by `control-server` itself, both ed25519 and rsa
**IMPORTANT**: Do not add passphrases to these SSH keys, since these will be used by `control-server` itself unattended, and will not work otherwise!

First, create the ed25519 key, which the age key (for `control-server` will derive from, by running this command: `ssh-keygen -t ed25519 -C "USERNAME@HOSTNAME"`

Now that you have your ed25519 SSH key, to derive the age key, run `nix run nixpkgs#ssh-to-age -- -private-key -i <DIRECTORY OF YOUR PRIVATE SSH KEY> -o <WHERE YOU WANT TO STORE YOUR AGE KEY>`

Next, create the rsa key, by running this command: `ssh-keygen -t rsa -b 4096 -C "USERNAME@HOSTNAME"`

TODO: Work out the directory part

Make sure you save these for the next steps.

### 1. Create an SSH key to create an age key for sops-nix, for your PC
For dealing with secrets in sops-nix, we will need an SSH key, used on your PC's end (the one that will access `control-server`), that we will use to derive an age key, which will be used to encrypt/decrypt our secrets later on, in the instantiation process. Importantly, the key's format **HAS** to be `ed25519` for this to work.

To create an ed25519 SSH key, simply run `ssh-keygen -t ed25519 -C "PCUSERNAME@PCHOSTNAME"`

Now that you have your ed25519 SSH key, to derive the age key, run `nix run nixpkgs#ssh-to-age -- -private-key -i <DIRECTORY OF YOUR PRIVATE SSH KEY> -o $HOME/.config/sops/age/keys.txt`

(The directory for `-o` can be anything, but, by default, `sops-nix` will look for your keys at `$HOME/.config/sops/age/keys.txt`)

If using Ansible, you might want to store the SSH key and/or age key in the vault.

NOTE: Alternatively, to just create an age key, run `nix shell nixpkgs#age --command age-keygen -o $HOME/.config/sops/age/keys.txt`)

### 2. Create/fill out `.sops.yaml`
Now that we have our age keys created, we will need to fill out `.sops.yaml` with our public age keys and the details of how we want to deal with our `secrets.yaml` file, for sops-nix to work.

First, we will need to derive the public keys from our private age key files.

For your ed25519 SSH keys from steps 0 and 1, get their public keys by running this command for each: `cat <DIRECTORY OF AGE PRIVATE KEY FILE> | nix shell nixpkgs#age --command age-keygen -y`

Now that you have your public keys, create (or fill out) `.sops.yaml`, in the root directory of the repo with this information in `keys`:

```yaml
keys: # Note: The names can be anything, they just need to match to what is in the creation_rules section
  - &admin agePUBLICKEYFORMAINPC
  - &control_server agePUBLICKEYFORCONTROLSERVER
```

Furthermore, in `.sops.yaml`, add this information in `creation_rules` as a new entry (the contents of `path_regex` are just the path to the `secrets.yaml` in your soon-to-be instance directory, feel free to change it):
```yaml
creation_rules:
  - path_regex: instances/control-server/secrets.yaml # Control server
    key_groups:
    - age: # This is the list of the users, of whom their encryption keys will be used to encrypt the secrets in a way that only one decryption key is needed at a time
      - *admin
      - *control_server
```

Ultimately, barring anything else that exists in `.sops.yaml`, you should have something that looks like this:
```yaml
keys:
  - &admin agePUBLICKEYFORMAINPC
  - &control_server agePUBLICKEYFORCONTROLSERVER

creation_rules:
  - path_regex: instances/control-server/secrets.yaml # Control server
    key_groups:
    - age:
      - *admin
      - *control_server
```

### 3. Create `secrets.yaml` (the secrets file)
With `.sops.yaml` ready in the root directory of the repository, you are now able to create the list of secrets, in `secrets.yaml`.

First, create the directory, `<REPO>/instances/control-server` (if it does not exist yet), and within that directory, create a file named `secrets.yaml` (the secrets file), using this command: `EDITOR=nano nix run nixpkgs#sops -- ./instances/control-server/secrets.yaml` (ensure your working directory is the repository's root directory)

NOTE: `control-server` in `./instances/control-server/` is just the name of the instance; you are welcome to change this to anything else, as long as it is kept consistent as you follow the whole guide.

This command puts you into a text editor, where you can edit the actual contents of your secrets file; once you save your changes, sops will automatically encrypt the file with the public age keys from `.sops.yaml`. You can use the above command multiple times to edit the contents of the secrets file whenever you need to.

Now that you are editing the secrets file, you will need to fill it out with various secrets, ranging from API keys, to passwords, to other tokens that you will want to keep out of cleartext.

For `control-server`, here is a list of secrets you will need to set:

- main-password: Your login password, for ease of reference
- main-password-hashed: The hash of your login password (create by passing your password into `nix run nixpkgs#mkpasswd -- -m sha-512 -s`)
- tailscale-auth-key: [Authentication key for Tailscale](https://tailscale.com/kb/1085/auth-keys)
- komodo-db-pass: Password for the SQL server of Komodo
- komodo-passkey: Passkey for authenticating between Komodo Core / Periphery
- semaphore-admin-pass: Password for the admin account of Semaphore
- semaphore-db-pass: Password for the SQL server of Semaphore
- semaphore-encryption-key: Key for encrypting access keys in database for Semaphore (generate with `head -c32 /dev/urandom | base64`)
- semaphore-email-user: Username to use for the SMTP relay server
- semaphore-email-pass: Password to use for the SMTP relay server
- namecheap-api-details: [Namecheap username and API key for DNS challenges](https://www.namecheap.com/support/api/intro/)
  - You will want this in this format:
    ```yaml
    namecheap-api-details: |
      dns_namecheap_username=YOURUSERNAME
      dns_namecheap_api_key=SETYOURAPIKEYHERE
    ```

Generally, you'll want something in this format:
```yaml
secret1: mysecretkey1
secret2: mysecretkey2
multilinesecret: |
  secretkey3
  secretkey4
```

To exit, simply press `Ctrl+X` and type `y`. After this, you will see that `secrets.yaml` will look different, but still have info for each field (just encrypted). To edit the contents of file again, simply run the same command from before.

### 4. Create the instance values
In the directory, `<REPO>/instances/control-server`, create a file named `instance-values.toml` with these values:
- `hostname` (string): The main hostname to use for the instance (e.g. `control-server`)
- `domain` (string): The domain to use, which, combined with the hostname, constitutes the FQDN of the instance (e.g. `int-net.saphnet.xyz`)
- `authorized-keys` (array of strings): A list of public keys (from step 0) that are authorized to connect to `control-server`
- `networking` (table)
  - `ip-address` (string): The IP address to use for the instance (e.g. `192.168.8.211`)
  - `ip-prefix-length` (integer): The length of the prefix that the IP address falls under (e.g. `24`)
  - `interface` (string): The name of the interface to use for the main connection (typically `ens18`)
- `ansible-control` (table)
  - `web-root` (string): The full URL that Semaphore UI uses and advertises, with no trailing slashes (e.g. `https://semaphore.int.saphnet.xyz`)

### 5. Add an entry in `flake.nix` for `control-server`
Now that we have the different values and secrets configured for our instance, we will need to actually turn the instance into something accessible as a NixOS configuration, within `flake.nix`. This will be used by install scripts and updaters (e.g. nixos-anywhere) to set up the particular configuration of a machine, with the values of an instance, in this case, being `control-server`.

Our `flake.nix` file will look something like this:
```nix
{
  description = "...";
  
  inputs = {...};

  outputs =
    {
      ...
    } @ inputs: let
      inherit (self) outputs;
    in {
      nixosConfigurations = {
        "server1" = nixpkgs.lib.nixosSystem {...};
        "server2" = nixpkgs.lib.nixosSystem {...};
        ...
      };
    };
}

```

`nixosConfigurations` in `outputs`, is where we will want to put our configuration for our instance, `control-server`.

It should look like this:
```nix
nixosConfigurations = {
  ...
  "control-server" = nixpkgs.lib.nixosSystem {
    specialArgs = {inherit inputs outputs;};
    system = "x86_64-linux";
    modules = [
      machines/control-server/hardware-configuration.nix
      (import modules/disko/impermanence-btrfs.nix { device = "/dev/sda"; })
      (import machines/control-server/configuration.nix {
        secretsFile = "${./instances/control-server/secrets.yaml}"; 
        instanceValues = builtins.fromTOML (builtins.readFile "${./instances/control-server/instance-values.toml}"); 
        constantsValues = builtins.fromTOML (builtins.readFile "${./constants/homelab-constants-values.toml}"); 
      })
    ];
  };
  ...
};
```

In this configuration:
- `"control-server"` is the name of the NixOS configuration that will be referred to by installers using the flake in this repository (e.g. `nix run github:nix-community/nixos-anywhere -- --flake .#control-server ...`)
- We are using x86_64 processors, for NixOS (Linux), so `system` is set to `x86_64-linux`.
- `machines/control-server/hardware-configuration.nix` will be generated automatically by nixos-anywhere.
- As we are using Disko, we need to pass in a Disko configuration for this NixOS configuration, which will be `impermanence-btrfs.nix` in this case. Furthermore, we need to state the name of the disk device that will be formatted and used for our system, which is `/dev/sda` in this case (as we use SCSI drives in Proxmox).
- `machines/control-server/configuration.nix` is the main configuration file for `control-server`, but we will need to give it instance values so that particular names, details, and secrets can populate this file. This is done by passing various file paths and the parsed contents of files for our instance:
  - `secretsFile` is the path to our sops secrets file, being `<REPO>/instances/control-server/secrets.yaml` (from step 3).
  - `instanceValues` is the values for this instance, being the parsed contents of `<REPO>/instances/control-server/instance-values.toml` (from step 4).
  - `constantsValues` is the values of constants that are shared among various machines in a certain group (in this case, Sapphic Homelab machines), being the parsed contents of `<REPO>/constants/homelab-constants-values.toml`.

Now that we have an entry in `nixosConfigurations` for our particular instance, we are now able to get to the deployment part of the process.

## Steps to deploy and install `control-server`
TODO: Finish here, think about how you'd do Ansible

Something like moving the SSH and age keys into a directory structure that matches root (in persist dir), finding a way to automate the SSH key passphrase process, nixos-anywhere, etc

## Steps to update `control-server`
TODO: Finish here