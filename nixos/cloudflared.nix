{ config, lib, pkgs, modulesPath, ... }:

let
  # Import secrets from the file described in the readme
  secrets = import /etc/chuck-stack/secrets/keys.nix;
in {
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
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token=${secrets.cloudflaredToken}";
      Restart = "always";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };
}

# References:
  # https://discourse.nixos.org/t/using-cloudflared-with-zero-trust-dashboard-on-nixos/19069/7
# Notes:
  # This configuration requires a secrets file at /etc/chuck-stack/secrets/keys.nix
  # The secrets file should contain: { cloudflaredToken = "your-actual-token"; }
  # See the project readme.md for instructions on setting up the secrets file with proper permissions
