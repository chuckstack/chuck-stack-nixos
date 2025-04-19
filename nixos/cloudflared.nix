{ config, lib, pkgs, modulesPath, ... }:

{
  environment.systemPackages = with pkgs; [
    # jdk17_headless
    # maven
    cloudflared
  ];

  users.users.cloudflared = {
    group = "cloudflared";
    isSystemUser = true;
  };
  users.groups.cloudflared = { };

  systemd.services.my_tunnel = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "systemd-resolved.service" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token=<token>";
      Restart = "always";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };
}

# References:
  # https://discourse.nixos.org/t/using-cloudflared-with-zero-trust-dashboard-on-nixos/19069/7
# Notes:
  # ideally, --credentials-file should be used instead of --token since that token is sensitive
