{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
with lib; let
  cfg = config.services.anki-sync-server;
  name = "anki-sync-server";
  specEscape = replaceStrings ["%"] ["%%"];
in {
  options.services.anki-sync-server = {
    enable = mkEnableOption (lib.mdDoc "anki-sync-server");

    package = mkOption {
      type = types.package;
      default = pkgs.anki-bin;
      defaultText = literalExpression "pkgs.anki-bin";
      description = lib.mdDoc "The package to use for the anki command.";
    };

    host = mkOption {
      type = types.str;
      default = "localhost";
      description = lib.mdDoc "anki-sync-server host";
    };

    port = mkOption {
      type = types.port;
      default = 27701;
      description = lib.mdDoc "anki-sync-server port";
    };

    openFirewall = mkOption {
      default = false;
      type = types.bool;
      description = lib.mdDoc "Whether to open the firewall for the specified port.";
    };

    users = mkOption {
      type = with types;
        listOf (submodule {
          options = {
            username = mkOption {
              type = str;
              description = lib.mdDoc "User name accepted by anki-sync-server.";
            };
            password = mkOption {
              type = str;
              description = lib.mdDoc ''
                Password accepted by anki-sync-server for the associated username.
                **WARNING**: This option is **not secure**. This password will
                be stored in *plaintext* and will be visible to *all users*.
                See {option}`services.anki-sync-server.users.passwordFile` for
                a more secure option. Note that this option doesn't support
                passwords that begin with the `/` character.
              '';
            };
            passwordFile = mkOption {
              type = path;
              description = lib.mdDoc ''
                File containing the password accepted by anki-sync-server for
                the associated username.  Make sure to make readable only by
                root.
              '';
            };
          };
        });
      description = lib.mdDoc "List of user-password pairs to provide to the sync server.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.length cfg.users > 0;
        message = "At least one username-password pair must be set.";
      }
      {
        assertion =
          (
            builtins.compareVersions
            (elemAt (builtins.match ".*-(([0-9]+\\.)*[0-9]+)$" cfg.package.name) 0)
            "2.1.66"
          )
          != -1;
        message = "anki package <2.1.66 not supported by this module. Earliest supported commit: https://github.com/NixOS/nixpkgs/commit/05727304f8815825565c944d012f20a9a096838a";
      }
    ];
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];

    systemd.services.anki-sync-server = {
      description = "anki-sync-server: Anki sync server built into Anki";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      path = [cfg.package];
      environment =
        {
          SYNC_BASE = "%S/%N";
          SYNC_HOST = specEscape cfg.host;
          SYNC_PORT = toString cfg.port;
        }
        // (
          attrsets.mergeAttrsList
          (lists.imap1
            (i: user: {"SYNC_USER${toString i}" = ''${specEscape user.username}:${
                if user ? passwordFile
                then "%d/${specEscape user.username}"
                else specEscape user.password
              }'';})
            cfg.users)
        );

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = name;
        ExecStart = "${pkgs.bash}/bin/bash -c ${utils.escapeSystemdExecArg ''
            # When services.anki-sync-server.users.passwordFile is set above,
            # we set the "password" in the SYNC_USER* environment variables
            # to the path of the password file, as exposed to the service.
            # Since Anki sync server requires passwords to be passed via
            # environment variable, here we replace each path with the content
            # of the password file before launching the server.
            user_vars=$(env | grep -oE '^SYNC_USER[0-9]+')
            for var in ''$user_vars; do
              eval "val=\''${''$var}";
              user=''${val%%:*}
              pass=''${val#*:}
              # Only replace passwords that are paths (that begin with `/`).
              if ! [[ "''$pass" = "''${pass##*/}" ]]; then
                eval ''$var=''$(printf '%q' "''$user"):''$(printf '%q' ''$(cat "''$pass"))
              fi
            done
            exec ${cfg.package}/bin/anki --syncserver
          '
        ''}";
        Restart = "always";
        LoadCredential =
          map
          (user: "${specEscape user.username}:${specEscape (toString user.passwordFile)}")
          (filter (user: user ? passwordFile) cfg.users);
      };
    };
  };

  meta = {
    maintainers = with maintainers; [telotortium];
    doc = ./anki-sync-server.md;
  };
}
