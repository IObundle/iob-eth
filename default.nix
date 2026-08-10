# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only

{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz") {} }:

let
  py2hwsw_commit = "20f93d7d9c7fa25960889c822e6a05a61e681149"; # Replace with the desired commit.
  py2hwsw_sha256 = "lRdQTSBUAXazHzaGc+iTnKmWd74JiRqK+znZjbxnpgc="; # Replace with the actual SHA256 hash.
  # Get local py2hwsw root from `PY2HWSW_ROOT` env variable
  py2hwswRoot = builtins.getEnv "PY2HWSW_ROOT";

  # For debug
  force_py2_build = 0;

  py2hwsw = 
    # If no root is provided, or there is a root but we want to force a rebuild
    if py2hwswRoot == "" || force_py2_build != 0 then
      pkgs.python3.pkgs.buildPythonPackage rec {
        pname = "py2hwsw";
        version = py2hwsw_commit;
        src =
          if py2hwswRoot != "" then
            # Root provided, use local
            pkgs.lib.cleanSource py2hwswRoot
          else
            # No root provided: fetch from GitHub and add shortHash.tex
            (pkgs.fetchFromGitHub {
              owner = "IObundle";
              repo = "py2hwsw";
              rev = py2hwsw_commit;
              sha256 = py2hwsw_sha256;
              fetchSubmodules = true;
              # Generate shortHash.tex based on commit
              postFetch = ''
                echo "Creating shortHash.tex"
                echo "${builtins.substring 0 7 py2hwsw_commit}" > "$out/py2hwsw/shortHash.tex"
              '';
            }).overrideAttrs (_: {
              GIT_CONFIG_COUNT = 1;
              GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
              GIT_CONFIG_VALUE_0 = "git@github.com:";
            });
        # Add any necessary dependencies here.
        #propagatedBuildInputs = [ pkgs.python38Packages.someDependency ];
      }
    else
      null;

  extra_pkgs = with pkgs; [
    # Define other Nix packages for your project here
  ];

in

# If no root is provided, or there is a root but we want to force a rebuild
if py2hwswRoot == "" || force_py2_build != 0 then
  # Use newly built nix package
  import "${py2hwsw}/lib/python${builtins.substring 0 4 pkgs.python3.version}/site-packages/py2hwsw/lib/default.nix" { py2hwsw_pkg = py2hwsw; extra_pkgs = extra_pkgs; }
else
  # Use local
  import "${py2hwswRoot}/py2hwsw/lib/default.nix" { py2hwsw_pkg = py2hwsw; extra_pkgs = extra_pkgs; }
