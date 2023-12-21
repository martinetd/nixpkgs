{ config, lib, pkgs, ... }:

let
  cfg = config.services.cryptpad;

  inherit (lib) strings mdDoc mkOption types mkIf mkMerge;

  # The Cryptpad configuration file isn't JSON, but a JavaScript source file that assigns a JSON value
  # to a variable.
  cryptpadConfigFile = builtins.toFile "cryptpad_config.js" ''
    module.exports = ${builtins.toJSON cfg.settings}
  '';

  # Derive domain names for Nginx configuration from Cryptpad configuration
  mainDomain = strings.removePrefix "https://" cfg.settings.httpUnsafeOrigin;
  sandboxDomain = if isNull cfg.settings.httpSafeOrigin then mainDomain else strings.removePrefix "https://" cfg.settings.httpSafeOrigin;

in {
  options.services.cryptpad = {
    enable = lib.mkEnableOption "cryptpad";

    package = lib.mkPackageOption pkgs "cryptpad" {};

    configureNginx = mkOption {
      description = mdDoc ''
        Configure Nginx as a reverse proxy for Cryptpad.
        Note that this makes some assumptions on your setup, and sets settings that will
        affect other virtualHosts running on your Nginx instance, if any.
        Alternatively you can configure a reverse-proxy of your choice.
      '';
      type = types.bool;
      default = false;
    };

    confinement = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        FIXME: Enables 'confinement' (explain what it does?)
        Enable the nixos systemd.services.cryptpad.confinement setting, including the necessary
        extra bind mounts.
      '';
    };

    settings = mkOption {
      description = mdDoc ''
        Cryptpad configuration settings.
        See https://github.com/cryptpad/cryptpad/blob/main/config/config.example.js for a more extensive
        reference documentation.
        Test your deployed instance through `https://<domain>/checkup/`.
      '';
      type = types.submodule {
        freeformType = (pkgs.formats.json {}).type;
        options = {
          httpUnsafeOrigin = mkOption {
            type = types.str;
            example = "https://cryptpad.example.com";
            default = "";
            description = mdDoc "This is the URL that users will enter to load your instance";
          };
          httpSafeOrigin = mkOption {
            type = types.nullOr types.str;
            example = "https://cryptpad-ui.example.com. Apparently optional but recommended.";
            description = mdDoc "Cryptpad sandbox URL";
          };
          httpAddress = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = mdDoc "Address on which the Node.js server should listen";
          };
          httpPort = mkOption {
            type = types.int;
            default = 3000;
            description = mdDoc "Port on which the Node.js server should listen";
          };
          maxWorkers = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = mdDoc "Number of child processes, defaults to number of cores available";
          };
          adminKeys = mkOption {
            type = types.listOf types.str;
            default = [];
            description = mdDoc "List of public signing keys of users that can access the admin panel";
            example = [ "[cryptpad-user1@my.awesome.website/YZgXQxKR0Rcb6r6CmxHPdAGLVludrAF2lEnkbx1vVOo=]" ];
          };
          logToStdout = mkOption {
            type = types.bool;
            default = true;
            description = mdDoc "Controls whether log output should go to stdout of the systemd service";
          };
          logLevel = mkOption {
            type = types.str;
            default = "info";
            description = mdDoc "Controls log level";
          };
          blockDailyCheck = mkOption {
            type = types.bool;
            default = true;
            description = mdDoc "Disable telemetry. This setting is only effective if the 'Disable server telemetry' setting in the admin menu has been untouched, and will be ignored once set there either way.";
          };
          installMethod = mkOption {
            type = types.str;
            default = "nixos";
            description = mdDoc ''
              Install method is listed in telemetry if you agree to it through the consentToContact
              setting in the admin panel.
            '';
          };
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      users.users.cryptpad = {
        isSystemUser = true;
        group = "cryptpad";
      };
      users.groups.cryptpad = {};

      systemd.services.cryptpad = {
        description = "Cryptpad service";
        wantedBy = [ "multi-user.target" ];
        after = [ "networking.target" ];
        serviceConfig = {
          User = "cryptpad";
          Environment = [
            "CRYPTPAD_CONFIG=${cryptpadConfigFile}"
            "HOME=%S/cryptpad"
          ];
          ExecStart = lib.getExe cfg.package;
          PrivateTmp = true;
          Restart = "always";
          StateDirectory = "cryptpad";
          WorkingDirectory = "%S/cryptpad";
        };
      };
    }
    (mkIf cfg.confinement {
      systemd.services.cryptpad = {
        serviceConfig.BindReadOnlyPaths = [
          cryptpadConfigFile
          # apparently needs proc for workers management
          "/proc"
          "/dev/urandom"
        ] ++ (if ! cfg.settings.blockDailyCheck then [
          "/etc/resolv.conf"
          "/etc/hosts"
        ] else []);
        confinement = {
          enable = true;
          binSh = null;
          mode = "chroot-only";
        };
      };
    })
    (mkIf cfg.configureNginx {
      assertions = [
        { assertion = cfg.settings.httpUnsafeOrigin != "";
          message = "services.cryptpad.settings.httpUnsafeOrigin is required";
        }
        { assertion = strings.hasPrefix "https://" cfg.settings.httpUnsafeOrigin;
          message = "services.cryptpad.settings.httpUnsafeOrigin must start with https://";
        }
        { assertion = isNull cfg.settings.httpSafeOrigin || strings.hasPrefix "https://" cfg.settings.httpSafeOrigin;
          message = "services.cryptpad.settings.httpSafeOrigin must start with https:// (or be unset)";
        }
      ];
      services.nginx = {
        enable = true;
        recommendedTlsSettings = true;

        # FIXME: Check / compare this with [Nginx module configuration in nixpkgs](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/nixos/modules/services/web-servers/nginx/default.nix).
        # Find out why Cryptpad has this in their documetation. Does this decrease the security of a Cryptpad install
        # if not used?
        # diffie-hellman parameters are used to negotiate keys for your session
        # generate strong parameters using the following command
        # ssl_dhparam /etc/nginx/dhparam.pem; # openssl dhparam -out /etc/nginx/dhparam.pem 4096
        #
        # sslDhparam = null;

        # FIXME: Check / compare this with [Nginx module configuration in nixpkgs](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/nixos/modules/services/web-servers/nginx/default.nix).
        # Find out why Cryptpad has this in their documentation. Does this decrease the security of a Cryptpad install
        # if not used?
        # replace with the IP address of your resolver
        # resolver 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9 149.112.112.112 208.67.222.222 208.67.220.220;
        #
        # resolver = {};

        virtualHosts = mkMerge [
          {
            "${mainDomain}" = {
              serverAliases = if isNull cfg.settings.httpSafeOrigin then [ ] else [ sandboxDomain ];
              # NOTE: I see no reason not to enable ACME and forcing SSL if you enable Nginx for
              # Cryptpad, IMHO. Given the security context of Cryptpad, it should only ever be used with SSL.
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${cfg.settings.httpAddress}:${builtins.toString cfg.settings.httpPort}";
                proxyWebsockets = true;
                extraConfig = ''
                  client_max_body_size 150m;
                '';
              };
            };
          }
        ];
      };
    })
  ]);
}
