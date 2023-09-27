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
  usersWithIndexes =
    lists.imap1 (i: user: {
      i = i;
      user = user;
    })
    cfg.users;
  usersWithIndexesFile = filter (x: x.user.passwordFile != null) usersWithIndexes;
  usersWithIndexesNoFile = filter (x: x.user.passwordFile == null && x.user.password != null) usersWithIndexes;
  anki-sync-server-run = pkgs.writeShellScriptBin "anki-sync-server-run" ''
    # When services.anki-sync-server.users.passwordFile is set,
    # each password file is passed as a systemd credential, which is mounted in
    # a file system exposed to the service. Here we read the passwords from
    # the credential files to pass them as environment variables to the Anki
    # sync server.
    ${
      concatMapStringsSep
      "\n"
      (x: ''export SYNC_USER${toString x.i}=${strings.escapeShellArg x.user.username}:"''$(cat "''${CREDENTIALS_DIRECTORY}/"${strings.escapeShellArg x.user.username})"'')
      usersWithIndexesFile
    }
    # For users where services.anki-sync-server.users.password isn't set,
    # export passwords in environment variables in plaintext.
    ${
      concatMapStringsSep
      "\n"
      (x: ''export SYNC_USER${toString x.i}=${strings.escapeShellArg x.user.username}:${strings.escapeShellArg x.user.password}'')
      usersWithIndexesNoFile
    }
    exec ${cfg.package}/bin/anki --syncserver
  '';
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
              type = nullOr str;
              default = null;
              description = lib.mdDoc ''
                Password accepted by anki-sync-server for the associated username.
                **WARNING**: This option is **not secure**. This password will
                be stored in *plaintext* and will be visible to *all users*.
                See {option}`services.anki-sync-server.users.passwordFile` for
                a more secure option.
              '';
            };
            passwordFile = mkOption {
              type = nullOr path;
              default = null;
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
        assertion = (builtins.length usersWithIndexesFile) + (builtins.length usersWithIndexesNoFile) > 0;
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
      environment = {
        SYNC_BASE = "%S/%N";
        SYNC_HOST = specEscape cfg.host;
        SYNC_PORT = toString cfg.port;
      };

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = name;
        ExecStart = "${anki-sync-server-run}/bin/anki-sync-server-run";
        Restart = "always";
        LoadCredential =
          map
          (x: "${specEscape x.user.username}:${specEscape (toString x.user.passwordFile)}")
          usersWithIndexesFile;
      };
    };
  };

  meta = {
    maintainers = with maintainers; [telotortium];
    doc = ./anki-sync-server.md;
  };
}
