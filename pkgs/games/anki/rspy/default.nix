{ stdenv
, fetchFromGitHub
, rustPlatform
, bash
, protobuf
, maturin
, python3
, runCommand
, openssl
, pkgconfig
, perl
, rustfmt

# from anki package
, version
, src
}:

let
  pname = "ankirspy";
in

rustPlatform.buildRustPackage {
  inherit pname version src;

  sourceRoot = "anki-source/rspy";

  cargoPatches = [
    ./add-Cargo.lock.patch
  ];

  cargoSha256 = "sha256-o2vhJVmXJH5LhjjmxkRL6qnYvGcT4kFyDnTwcUUaZKA=";

  buildInputs = [
    openssl
  ];

  nativeBuildInputs = [
    rustfmt
    pkgconfig
    perl
    python3
  ];

  postPatch = ''
    # It tries to execute the vendored protoc binary during the build of rslib, we need to replace it with Nix'
    rm $NIX_BUILD_TOP/$cargoDepsCopy/prost-build/third-party/protobuf/protoc-linux-x86_64
    ln -s ${protobuf}/bin/protoc $NIX_BUILD_TOP/$cargoDepsCopy/prost-build/third-party/protobuf/protoc-linux-x86_64

    # Remove now invalid checksum
    # Taken from pkgs/development/python-modules/tokenizers/
    sed -r -i 's|"files":\{[^}]+\}|"files":{}|' \
      $NIX_BUILD_TOP/$cargoDepsCopy/prost-build/.cargo-checksum.json
  '';

  buildPhase = ''
    # build tries to write in sources (.. is sources copy root), make writable...
    chmod -R u+w ..

    HOME=$NIX_BUILD_TOP
    FTL_TEMPLATE_DIRS="../qt/ftl" QT_FTL_LOCALES="../qt/ftl/repo/desktop" \
        ${maturin}/bin/maturin build -o $out --release --strip
  '';

  # Maturin installs by itself and this would fail anyways
  dontInstall = true;

  # pyo3 breaks cargo test.. for a while now.
  # https://github.com/PyO3/pyo3/issues/341
  # Workaround given in issue doesn't seem to work, so skip tests
  doCheck = false;
}
