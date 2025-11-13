# Scheduled service to automatically prune Docker containers, images, etc
{
  pkgs,
  ...
}:
{
  systemd.services."docker-autoprune" = {
    enable = true;
    serviceConfig.Type = "oneshot";
    script = with pkgs; ''
      # Removes all unused images, containers, etc created more than 10 days ago
      ${pkgs.docker}/bin/docker system prune --all --force --filter "until=240h"
    '';
  };
  systemd.timers."docker-autoprune" = {
    enable = true;
    wantedBy = [ "timers.target" ];
    partOf = [ "docker-autoprune.service" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 02:00:00"; # Every Sunday at 2:00 AM
      Persistent = true;
      RandomizedDelaySec = "10m";
      Unit = "docker-autoprune.service";
    };
  };
}