{ stdenv
, fetchFromGitHub
, rustPlatform
, bash
, protobuf
, maturin
, python3
, runCommand
, rustup
}:

rustPlatform.buildRustPackage rec {
  pname = "orjson";
  version = "3.4.1";

  src = fetchFromGitHub {
  	owner = "ijl";
	repo = "orjson";
	rev = version;
	sha256 = "0acz7syxbxc988cjrlikxrzls4vrdnaymhy8j9vkp2hjmvh9kq6v";
  };

  cargoSha256 = "sha256-e5ZN83nWcZxuq2JjqAnhvtNYJ2j8JIhCq8rQPzZGeVg=";

  buildInputs = [
  ];

  nativeBuildInputs = [
    rustup
    python3
    maturin
  ];

  buildPhase = ''
    HOME=$NIX_BUILD_TOP
    rustup override set nightly-2020-10-19
    maturin build -o $out --release --strip
  '';

  # Maturin installs by itself and this would fail anyways
  dontInstall = true;

  # pyo3 breaks cargo test.. for a while now.
  # https://github.com/PyO3/pyo3/issues/341
  # Workaround given in issue doesn't seem to work, so skip tests
  doCheck = false;
}
