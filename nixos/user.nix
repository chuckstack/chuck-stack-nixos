{ config, lib, pkgs, modulesPath, ... }:

# Example: file to manage users

# Example: example of how to pull/clone files from github
# Example: get ssh public from github
let
  chuboeKeys = pkgs.fetchFromGitHub {
    owner = "cboecking";
    repo = "keys";
    rev = "main";  # or any other branch or commit hash
    sha256 = "sha256-+KTI8xKp6/CMOVMsJYHQ7eMUwJEN8euNRKV9/7o3ECg";  # replace with actual hash
  };
  chuboeAuthKeys = "${chuboeKeys}/id_rsa.pub";
in
#let
#  # Example: alternate way to get something from github
#  chuboeAuthKeyUrl = "https://raw.githubusercontent.com/cboecking/keys/refs/heads/main/id_rsa.pub";
#  chuboeAuthKeys = pkgs.fetchurl {
#    url = chuboeAuthKeyUrl;
#    sha256 = "sha256-P6urHYR0fpoy+TF4xTzDdqf8ao894QEk1XQ/TbT0TLQ"; #note: an empty string removes the hash check - nix will complain
#  };
#in
{
  # Example: create both interactive login and system non-login user
  users.users = {
    # Real sudo user that can log in
    chuboe = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ]; # Add any other groups as needed
      openssh.authorizedKeys.keyFiles = [ chuboeAuthKeys ];

      # Add other user-specific configurations here
      packages = with pkgs; [
        #firefox
        #thunderbird
      ];
    };

    # Service user without login capabilities
    serviceuser = {
      isSystemUser = true;
      group = "serviceuser";
      description = "User for running services";

      # uncomment these lines if you need the user to have a home
      #home = "/var/lib/serviceuser";
      #createHome = true;
      #shell = pkgs.bashInteractive;  # or pkgs.nologin if you want to prevent interactive login

    };
  };

  # Create a group for the service user
  users.groups.serviceuser = {};

}
