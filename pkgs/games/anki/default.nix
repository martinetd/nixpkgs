{ stdenv
, fetchFromGitHub
, callPackage
, runCommand
, python3Packages
}:

let
  version = "2.1.35";
  pname = "anki";

  srcAnki = fetchFromGitHub {
    owner = "ankitects";
    repo = pname;
    rev = version;
    sha256 = "0abz21yay9ljfimn6gmn29gxp5iflnxpvzjk219s9yb6nwv2w7li";
  };
  srcDesktopFtl = fetchFromGitHub {
    owner = "ankitects";
    repo = "anki-desktop-ftl";
    rev = "f56e959e00a65a9c2d059e8396a2d582b218ee50";
    sha256 = "07frldkm7vlxgrhjvg3fcx82ramvpla4191m1k2n1ydxq32hjlcn";
  };
  srcDesktopI18n = fetchFromGitHub {
    owner = "ankitects";
    repo = "anki-desktop-i18n";
    rev = "a93ccefd58d5ff49ecf6cae746d671dfc23248e9";
    sha256 = "sha256-0QMoirPziZq71lrIeWgL/N43WlLYPZFUa6GfvJ5FfYI=";
  };
  srcCoreI18n = fetchFromGitHub {
    owner = "ankitects";
    repo = "anki-core-i18n";
    rev = "fbda2ed1fdd176fa4eed7e397a6690d1a8453b75";
    sha256 = "09c1251kacfxd0ada48mh85vvpny8av6nxbr33w1cwrfhlrsax5s";
  };
  # do common preprocessing here instead of preBuild or similar to share
  # the same source for subpackages
  src = runCommand "anki-source" { inherit srcAnki srcDesktopFtl srcDesktopI18n srcCoreI18n version; } ''
    cp -a "${srcAnki}/." "$out"
    chmod u+w "$out/qt/ftl" "$out/qt/po" "$out/rslib/ftl" "$out/meta"
    cp -a "${srcDesktopFtl}" "$out/qt/ftl/repo"
    cp -a "${srcDesktopI18n}" "$out/qt/po/repo"
    cp -a "${srcCoreI18n}" "$out/rslib/ftl/repo"
    echo "${version}" > "$out/meta/buildhash"
  '';

  rspy = callPackage ./rspy { inherit src version; };

  ts = callPackage ./ts { src = src + "/ts"; };

  orjson = python3Packages.callPackage ./orjson { };

  pylib = python3Packages.callPackage ./pylib { inherit src orjson; };

in

python3Packages.buildPythonApplication {
  inherit src pname version rspy orjson;
  installPhase = ''
    cp -r "${rspy}" $out
  '';
}
