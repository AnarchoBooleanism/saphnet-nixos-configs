# NOTE: You need to set these sops-nix variables first before deploying!
# - main-password-hashed: Hash of the login password (pass this into "nix run nixpkgs#mkpasswd -- -m sha-512 -s")
# - tailscale-auth-key: Authentication key for Tailscale
# - komodo-db-pass: Password for the SQL server of Komodo
# - komodo-passkey: Passkey for authenticating between Komodo Core / Periphery
# - namecheap-api-details: Namecheap username and API key for DNS challenges

{ # Custom args
  secretsFile ? throw "Set this to the path of your instance's secrets file",
  instanceValues ? throw "Set this to the contents of your instance's values file",
  constantsValues ? throw "Set this to the contents of a constants values file",
}:
{
  inputs,
  config,
  modulesPath,
  lib,
  pkgs,
  ...
}:
let
  versionLock = lib.importTOML ./version-lock.toml;
  revProxyDomains = [ # Note: Order matters here! The first domain is used for the name of the SSL certificate.
    "komodo.int.saphnet.xyz"
  ];
in
{
  imports = [
    # NixOS modules
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    # Internal modules
    (../.. + "/modules/nix-setup-types/default.nix")
    (../.. + "/modules/system-types/proxmox-vm.nix")
    (../.. + "/modules/impermanence-types/default.nix")
    (import (../.. + "/modules/sops-nix-types/default-impermanence.nix") {
      inherit inputs secretsFile;
    })
    (../.. + "/modules/virtualization/docker.nix")
    (../.. + "/modules/virtualization/docker-extras/autoprune.nix")
    (../.. + "/modules/networking/tailscale.nix")
  ];

  sops = {
    secrets = {
      main-password-hashed = {
        neededForUsers = true; # Setting so that password works properly
      };
      tailscale-auth-key = {};
      komodo-db-pass = {};
      komodo-passkey = {};
      namecheap-api-details = {};
    };
  };

  environment.persistence."/persist" = { # Additional files to base ones
    directories = [
      "/var/lib/docker/" # Docker
      "/var/lib/tailscale/" # Tailscale
      "/etc/komodo" # Komodo
    ];
    files = [
      "/var/lib/reverse-proxy-bootstrap-complete" # For initial SSL cert bootstrapping
    ];
  };

  networking.hostName = instanceValues.hostname;
  networking.domain = instanceValues.domain;
  networking.defaultGateway = constantsValues.networking.gateway;
  networking.nameservers = constantsValues.networking.nameservers;
  networking.interfaces."${instanceValues.networking.interface}" = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = instanceValues.networking.ip-address;
        prefixLength = instanceValues.networking.ip-prefix-length;
      }
    ];
  };

  users.users = {
    "${constantsValues.default-username}" = {
      hashedPasswordFile = config.sops.secrets.main-password-hashed.path;
      isNormalUser = true;
      openssh.authorizedKeys.keys = constantsValues.authorized-keys; # Deployment key for accessibility
      extraGroups = ["wheel" "docker"];
    };

    root.hashedPassword = "!"; # Disable root login
  };

  time.timeZone = constantsValues.timezone;

  # Central Docker network used for communication between services
  systemd.services."central-network" = {
    description = "Creating central Docker network";

    wantedBy = ["multi-user.target"];
    after = [
      "docker.service" # Docker needed, of course
      "docker.socket"
    ];

    serviceConfig.Type = "oneshot";

    environment = {
      NETWORK_NAME = "central-network";
    };

    script = with pkgs; ''
      # Check if the network already exists
      if ! ${pkgs.docker}/bin/docker network inspect "$NETWORK_NAME" &> /dev/null; then
        # Network does not exist, so create it
        echo "Docker network '$NETWORK_NAME' not found. Creating it..."
        ${pkgs.docker}/bin/docker network create "$NETWORK_NAME"

        # Check the creation status
        if [ $? -eq 0 ]; then
          echo "Docker network '$NETWORK_NAME' created successfully."
        else
          echo "Error: Failed to create Docker network '$NETWORK_NAME'."
          exit 1
        fi
      else
        # Network already exists
        echo "Docker network '$NETWORK_NAME' already exists. Leaving it alone."
      fi
    '';
  };

  # Komodo control server, using Docker Compose for portability
  # NOTE: Komodo stores files in /etc/komodo
  # NOTE: MongoDB requires AVX support, so make sure you use the "host" CPU in Proxmox
  systemd.services."komodo-control" = {
    description = "Control server for Komodo, which manages Docker on multiple machines.";

    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = [
      "docker.service" # Docker needed, of course
      "docker.socket"
      "sops-nix.service" # Need to get secrets
      "network-online.target" # Need working internet to get things
      "central-network.service" # For communication with reverse proxy
    ];

    environment = {
      ENV_FILE = "${./komodo-control/compose.env}"; # Need to pass this in as env argument to work with Nix store
      # Other secret env variables that need to be passed in directly are listed in script 
    };

    script = with pkgs; ''
      # Waiting for the network to actually come online
      sleep 5

      # Dynamically export variables from secrets files
      export KOMODO_DB_PASSWORD=$(cat ${config.sops.secrets.komodo-db-pass.path})
      export KOMODO_PASSKEY=$(cat ${config.sops.secrets.komodo-passkey.path})

      # Export other variables
      export TZ=$(timedatectl show --va -p Timezone)

      ${pkgs.docker}/bin/docker compose -p komodo -f ${./komodo-control/mongo.compose.yaml} --env-file ${./komodo-control/compose.env} up
    '';
  };

  systemd.services."reverse-proxy-bootstrap" = {
    description = "Creating SSL certs (and volumes), with Certbot";

    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = [
      "docker.service" # Docker needed, of course
      "docker.socket"
      "sops-nix.service" # Need to get secrets
      "network-online.target"
    ];

    serviceConfig.Type = "oneshot"; # Really make sure reverse-proxy waits

    environment = {
      CERTBOT_IMAGE_TAG = "${versionLock.reverse-proxy.certbot-version}";

      CERTBOT_EMAIL = "${constantsValues.email.address}";
      CERTBOT_DOMAINS = "${lib.strings.concatStringsSep "," revProxyDomains}";

      # Other secret env variables that need to be passed in directly are listed in script 
      NAMECHEAP_API_DETAILS_FILE = "${config.sops.secrets.namecheap-api-details.path}";
    };

    script = with pkgs; ''
      # Exit early if already started, so reverse-proxy can start
      if [ -e /var/lib/reverse-proxy-bootstrap-complete ]; then
        echo "It appears that the reverse proxy bootstrapping process is completed. Exiting..."
        exit 0
      else
        echo "The reverse proxy bootstrapping process has not been started before. Starting now!"
      fi

      # Create the volumes
      echo "Creating volumes..."
      ${pkgs.docker}/bin/docker volume create certbot-conf

      # Run certbot standalone (custom image for Namecheap dns01 challenges)
      echo "Running Certbot..."
      ${pkgs.docker}/bin/docker run --rm \
        -v certbot-conf:/etc/letsencrypt \
        -v $NAMECHEAP_API_DETAILS_FILE:/namecheap.ini \
        ghcr.io/anarchobooleanism/certbot-dns-namecheap:$CERTBOT_IMAGE_TAG certonly \
        -a dns-namecheap \
        --dns-namecheap-credentials=/namecheap.ini \
        --agree-tos --non-interactive -vv \
        --no-eff-email \
        --email "$CERTBOT_EMAIL" \
        --domains "$CERTBOT_DOMAINS"

      # Now, create the file, marking completion.
      echo "Process completed, so we're marking this job as done..."
      ${pkgs.coreutils}/bin/touch /var/lib/reverse-proxy-bootstrap-complete
    '';
  };

  # NGINX reverse proxy for accessing the previous services securely
  systemd.services."reverse-proxy" = {
    description = "Reverse proxy, with NGINX";

    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    requires = ["reverse-proxy-bootstrap.service"]; # We need certbot to do its thing first
    after = [
      "docker.service" # Docker needed, of course
      "docker.socket"
      "sops-nix.service" # Need to get secrets
      "network-online.target" # Need working internet to get things
      "central-network.service" # For communication with reverse proxy
      "reverse-proxy-bootstrap.service"
    ];

    environment = {
      NGINX_CONF_FILE = "${./reverse-proxy/nginx.conf}";
      NGINX_PROXIES_FILE = "${./reverse-proxy/proxies.conf}";
      NGINX_CONFD_BLOCK_EXPLOITS_FILE = "${./reverse-proxy/nginx-conf.d/block-exploits.conf}";
      NGINX_CONFD_PROXY_FILE = "${./reverse-proxy/nginx-conf.d/proxy.conf}";
      NGINX_CONFD_SSL_FILE = "${./reverse-proxy/nginx-conf.d/ssl.conf}";
      NGINX_CONFD_IP_RANGES_FILE = "${./reverse-proxy/nginx-conf.d/ip-ranges.conf}";
      NGINX_AUTORELOAD_FILE = "${./reverse-proxy/99-autoreload.sh}";

      # Other secret env variables that need to be passed in directly are listed in script
      NAMECHEAP_API_DETAILS_FILE = "${config.sops.secrets.namecheap-api-details.path}";
    };

    script = with pkgs; ''
      # Waiting for the network to actually come online
      sleep 5

      export TZ=$(timedatectl show --va -p Timezone)

      ${pkgs.docker}/bin/docker compose -p reverse-proxy -f ${./reverse-proxy/compose.yaml} up
    '';
  };

  system.stateVersion = "${versionLock.state-version}";
}