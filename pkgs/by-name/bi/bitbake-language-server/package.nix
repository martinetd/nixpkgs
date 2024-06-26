{ lib
, nix-update-script
, python3
, fetchFromGitHub
}:

python3.pkgs.buildPythonApplication rec {
  pname = "bitbake-language-server";
  version = "0.0.8";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "Freed-Wu";
    repo = pname;
    rev = version;
    hash = "sha256-WJpa2LP95vrJG/OjiLSx8zEPO5ZOw66M5s3r2dufQJA=";
  };

  nativeBuildInputs = with python3.pkgs; [
    setuptools-scm
    setuptools-generate
  ];

  propagatedBuildInputs = with python3.pkgs; [
    oelint-parser
    pygls
  ];

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Language server for bitbake";
    mainProgram = "bitbake-language-server";
    homepage = "https://github.com/Freed-Wu/bitbake-language-server";
    changelog = "https://github.com/Freed-Wu/bitbake-language-server/releases/tag/v${version}";
    license = licenses.gpl3;
    maintainers = with maintainers; [ otavio ];
  };
}
