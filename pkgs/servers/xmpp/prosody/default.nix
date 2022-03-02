{ stdenv, fetchurl, lib, libidn, openssl, makeWrapper, fetchhg
, icu
, lua
, nixosTests
, withLibevent ? true
, withDBI ? true
# use withExtraLibs to add additional dependencies of community modules
, withExtraLibs ? [ ]
, withExtraLuaPackages ? _: [ ]
, withOnlyInstalledCommunityModules ? [ ]
, withCommunityModules ? [ ] }:

with lib;

let
  luaEnv = lua.withPackages(p: with p; [
      luasocket luasec luaexpat luafilesystem luabitop luadbi-sqlite3
      luaunbound luaossl
    ]
    ++ lib.optional withLibevent p.luaevent
    ++ lib.optional withDBI p.luadbi
    ++ withExtraLuaPackages p
  );
in
stdenv.mkDerivation rec {
  version = "0.12.1"; # also update communityModules
  pname = "prosody";
  # The following community modules are necessary for the nixos module
  # prosody module to comply with XEP-0423 and provide a working
  # default setup.
  nixosModuleDeps = [
    "cloud_notify"
    "cloud_notify_encrypted"
    "vcard_muc"
    "http_upload"
  ];
  src = fetchurl {
    url = "https://prosody.im/downloads/source/${pname}-${version}.tar.gz";
    sha256 = "sha256-p+y75B8BpCUYBVk6xtFdvGy3XZx6h2x2tFbPdP9LkOU=";
  };

  # A note to all those merging automated updates: Please also update this
  # attribute as some modules might not be compatible with a newer prosody
  # version.
  communityModules = fetchhg {
    url = "https://hg.prosody.im/prosody-modules";
    rev = "cce12a660b98";
    sha256 = "sha256-dFWS1EFd2wtFnnuU4xKPnBisIdKkgMAvBtsfAEbdLjE=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    luaEnv libidn openssl icu
  ]
  ++ withExtraLibs;

  configureFlags = [
    "--ostype=linux"
    "--with-lua-include=${luaEnv}/include"
    "--with-lua=${luaEnv}"
  ];

  postBuild = ''
    make -C tools/migration
  '';

  # the wrapping should go away once lua hook is fixed
  postInstall = ''
      ${concatMapStringsSep "\n" (module: ''
        cp -r $communityModules/mod_${module} $out/lib/prosody/modules/
      '') (lib.lists.unique(nixosModuleDeps ++ withCommunityModules ++ withOnlyInstalledCommunityModules))}
      wrapProgram $out/bin/prosodyctl \
        --add-flags '--config "/etc/prosody/prosody.cfg.lua"'
      make -C tools/migration install
    '';

  passthru = {
    communityModules = withCommunityModules;
    tests = { inherit (nixosTests) prosody prosody-mysql; };
  };

  meta = {
    description = "Open-source XMPP application server written in Lua";
    license = licenses.mit;
    homepage = "https://prosody.im";
    platforms = platforms.linux;
    maintainers = with maintainers; [ globin ];
  };
}
