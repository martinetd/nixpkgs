{ stdenv
, src
, rustPlatform
, bash
, pkgs # FIXME
}:

let
  pname = "ankirspy";
  version = "2.1.28";
in

rustPlatform.buildRustPackage {
  inherit pname version;
  # inherit src;
  # src = pkgs.runCommand "mkSubProject" { inherit src; } ''
  #   cp -a $src/rspy $out
  # '';
  src = pkgs.runCommand "source" { inherit src; lock = ./Cargo.lock; patch = ./pyo3-version.patch; } ''
    mkdir -p $out/rspy
    cp -r $src/. $out
    patch < $patch $out/rspy/Cargo.toml
    cp $lock $out/rspy/Cargo.lock
  '';

  sourceRoot = "source/rspy";

  cargoSha256 = "1yvnpvw3x9irsjgfhgmdrbz1fln6ai1xslfajsxh1xahiz90p6w5";

  buildInputs = with pkgs; [
    openssl
  ];
  nativeBuildInputs = with pkgs; [
    pkgconfig
    perl
  ];

  # pyo3 requires Rust nightly.
  RUSTC_BOOTSTRAP = 1;

  buildPhase = ''
    HOME=$NIX_BUILD_TOP
    RUST_BACKTRACE=full \
    FTL_TEMPLATE_DIRS="../qt/ftl" ${pkgs.maturin}/bin/maturin build -i ${pkgs.python3}/bin/python -o $out --release --strip
  '';
}
