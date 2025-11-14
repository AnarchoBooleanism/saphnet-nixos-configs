# Guide for deploying an Instance

> NOTE: You might want to perform this with the [Ansible playbook](https://github.com/AnarchoBooleanism/saphnet-ansible-playbook). However, the following may still be useful if you want to do everything manually, or if you want to integrate these steps into a new Ansible playbook.

With the creation of an Instance, you should now be able to deploy it to an actual machine. This process involves creating a virtual machine with the desired hardware setup, mounting the ISO image for [nixos-cloud-init-installer](https://github.com/AnarchoBooleanism/nixos-cloud-init-installer), setting up cloud-init with your connection details, running [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) with your Instance configuration, and then cleaning up after. This guide assumes that the system that you are using to remotely connect to your desired target system has Nix installed, with flakes and nix-commands enabled.

## Creating and configuring your virtual machine

In your hypervisor or virtual machine manager of choice, create a new virtual machine to install your NixOS configuration on. The details of your hardware configuration are all up to you, but it should reflect what the Machine and specified Disko configuration are looking for; NixOS is generally flexible, however, with the hardware configurations that it installs on. Make sure that you have enough CPU, RAM, and disk resources for the services and activities you want to do; as well, you'll want to make sure your CPU type and architecture are adequate for the software that you aim to run. If you're doing any hardware passthrough, you'll most likely want to use q35 instead of i440fx (if using QEMU/KVM). As well, you might want to set the MAC address of your virtual network interface to a pre-specified one, for DHCP to work consistently, if that is being used for the system or network. Most importantly, you'll want to make sure you have as many hard drives added as the selected Disko configuration asks for.

## Generating temporary SSH keys and configuring cloud-init

With your virtual machine created, you will need to set up cloud-init with the necessary details. Most importantly, you will need to set up the SSH public keys that the image for nixos-cloud-init-installer will accept, as it is configured to not connect with just a password; this can be a temporary SSH key that is separate to others that will be used once the deployment process is complete, as will be covered in this guide. Additionally, you'll also want to set up the IP address for cloud-init if you want the process to be automatic.

To generate a fresh SSH key just for nixos-cloud-init-installer, run this command:
```bash
ssh-keygen -t ed25519 -N ""
```

Note that we are not using a passphrase for this key, as it will lead to nixos-anywhere repeatedly asking for it when it is run, and as the key will be ephemeral, anyway. You are welcome to add a comment, with `-C "<COMMENT>"`, or use a cryptography algorithm of your choice (e.g. RSA).

Make sure to save this SSH key in a place where you can access it later.

With the SSH key now generated, `ssh-keygen` should have also saved the public key that nixos-cloud-init-installer can look for, in a `.pub` file. In the portal or other place where you set cloud-init settings, make sure to add the contents of this public key file to the list of authorized SSH keys. As well, if you do not want to type anything within the virtual machine during deployment, be sure to set the IP address for cloud-init so that it is set when the installer is booted up (or configure it to use DHCP). You are welcome to set other cloud-init settings, like the username and list of nameservers, but the SSH public key and, potentially, the IP address are the bare minimum settings that need to be set.

## Setting up files (SSH keys, etc) for nixos-anywhere to copy to the target directory

Before finally running nixos-anywhere, if there are any extra files, separate to anything included within the NixOS configuration repository, that need to be added to the file structure of the target system to be deployed, we will need to add them to a directory, within a subdirectory that matches where it will exist relative to the root directory. This will be needed for storing files like Instance-specific SSH keys and age keys for sops-nix.

For example, if you want the target system to have a file named `example-file.txt` in `/var/lib/example/` (this is relative to the root directory on the target system), and you are giving nixos-anywhere the directory, `$HOME/example-directory`, as the directory on your main system to copy over, you will want to place `example-file.txt` within `$HOME/example-directory/var/lib/example` so that nixos-anywhere copies it to the right location during deployment.

If you are using sops-nix to encrypt secrets, sops-nix on the target machine will need to have access to the age key, `keys.txt`, to decrypt these secrets at boot-time; this file is usually stored in `/var/lib/sops-nix/`. If you are giving nixos-anywhere the directory, `$HOME/example-directory`, as the directory to copy over to the target system, you will want to store this in `$HOME/example-directory/var/lib/sops-nix/`.

Furthermore, in addition to `keys.txt`, if you want to copy over SSH keys that are specific to the Instance (so that after a reinstall, the fingerprint isn't broken for other devices that want to connect to it via SSH), and you are giving nixos-anywhere the directory, `$HOME/example-directory`, as the directory to copy over to the target system, you'll want to place such keys in `$HOME/example-directory/etc/ssh/`.

This will be what `$HOME/example-directory/` will look like, with all the aforementioned files in their places relative to the root directory (corresponding to `$HOME/example-directory/` on the system running nixos-anywhere):
```
$HOME/example-directory (/ on the target system)
│
├─ etc
│   └ ssh
│      ├─ ssh_host_ed25519_key
│      ├─ ssh_host_ed25519_key.pub
│      ├─ ssh_host_rsa_key
│      └─ ssh_host_rsa_key.pub
└─ var
    └ lib
       └ sops-nix
          └ keys.txt
```

**NOTE**: If you are using Impermanence on your Machine, the whole subdirectory structure, relative to root, will need to be placed in the subdirectory (of the directory representing the root directory) that stores persistent files! Otherwise, these files will not be properly stored on the target system and will be erased after a reboot! For example, if the directory for persistent files is `/persist` (relative to the root subdirectory on the target system), and the directory that you are giving to nixos-anywhere is `$HOME/example-directory/`, you will need to place files in `$HOME/example-directory/persist/<LOCATION RELATIVE TO ROOT WHERE FILE WILL BE LOCATED>`.

This will be what `$HOME/example-directory/` will look like, with all the aforementioned files in their places relative to the root directory (`$HOME/example-directory/` on the system running nixos-anywhere):
```
$HOME/example-directory (/ on the target system)
│
└─ persist (all files under their respective subdirectories under here will be placed under / on the target system at boot-time!)
    ├─ etc
    │   └ ssh
    │      ├─ ssh_host_ed25519_key
    │      ├─ ssh_host_ed25519_key.pub
    │      ├─ ssh_host_rsa_key
    │      └─ ssh_host_rsa_key.pub
    └─ var
        └ lib
           └ sops-nix
              └ keys.txt
```
Everything that would be stored in `$HOME/example-directory/` is instead stored in `$HOME/example-directory/persist/`.

## Booting up nixos-cloud-init-installer and running nixos-anywhere

With all prerequisites for deployment ready, we are now able to start the installation process.

First, make sure the [ISO image for nixos-cloud-init-installer](https://github.com/AnarchoBooleanism/nixos-cloud-init-installer/releases) is mounted in the virtual CD-ROM drive of your virtual machine. Once the ISO image is mounted, start the virtual machine, and if there are any other existing boot options available, make sure to pick the CD-ROM drive to boot into.

Once the installer image has been completed booted into, you are welcome to check the network status of the live machine by running `ip addr`. You should be able to see that your main network interface has been set with the specific IP address, or if DHCP is configured with cloud-init, that an IP address has been assigned to the live machine.

On your main system (which has Nix installed, with flakes and nix-commands) that you are using to remotely connect to your target machine, with your working directory set as the root of this repository, you can now run nixos-anywhere with this command (make sure to fill in any blanks):
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#<INSTANCE_NAME> --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --target-host root@<IP ADDRESS/HOSTNAME> -i <PATH TO TEMPORARY SSH KEY>
```
NOTE: If you have extra files to copy to the target system, make sure to add the following to the command: `--extra-files <PATH TO DIRECTORY WITH EXTRA FILES>`

Assuming that everything works and all the prerequisites are in order, nixos-anywhere should do the following:
1. Connect to the target system via SSH, with the provided private key
2. Generate a hardware-configuration.nix file, tailored to the specific virtual machine
3. Format the target system's hard drive(s) and create their file systems
4. Download and build all necessary Nix packages for the Machine's NixOS configuration, either on the host (where nixos-anywhere is being run on) or the target machine
5. Copy over all the built Nix packages to the target machine
6. Install and configure NixOS on the target system
7. Copy over extra files to their corresponding locations, if provided

If nixos-anywhere is successful, it should reboot the system and then exit once it cannot connect to the target machine via SSH. You should be able to see the virtual machine properly boot into the new NixOS installation, and start all of its configured services.

## Cleaning up post-installation

With the deployment and installation process complete, you might want to clean up after any remaining artifacts, like cloud-init settings and temporary SSH keys.

First, you might want to clean up any cloud-init-related artifacts on the virtual machine. (If desired, you can shut down the virtual machine with the newly installed system.) To do this, go to the portal or location where cloud-init settings are configured, and remove and delete all specified details, such as SSH public keys and IP address details, as they are no longer needed; you are also welcome to remove cloud-init drive itself from the virtual machine if you do not anticipate having to use nixos-cloud-init-installer on the same machine again. After this, make sure to unmount the the ISO image for nixos-cloud-init-installer, so that there is no chance of the virtual machine booting into this image instead of the main operating system.

Finally, if you are using temporary SSH keys, you can delete those from your system, as they are no longer needed.

## Final words

By completing the deployment of an Instance, we therefore finish the step-by-step process of creating a NixOS system for the Sapphic Homelab, which started with just the building blocks of the Machine and its associated Modules. The deployment of an Instance is a big, multi-stage process, being part of the larger project of creating systems with NixOS for the Sapphic Homelab, with a plethora of system-specific considerations, but I hope that, with this guide, this process is rendered less intimidating and that you get a functional system for any needs that you have.