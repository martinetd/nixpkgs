{
  lib,
  fetchFromGitHub,
  buildGoModule,
  callPackage,
  enableWebui ? true,
  nixosTests,
}:

buildGoModule rec {
  pname = "rmfakecloud";
  version = "0.0.22";

  src = fetchFromGitHub {
    owner = "ddvk";
    repo = "rmfakecloud";
    rev = "v${version}";
    hash = "sha256-rOJ5q8JwvSPxHZ5n2UnltHG/ja6l7Z4pbnOWKjNG4hQ=";
  };

  vendorHash = "sha256-9tfxE03brUvCYusmewiqNpCkKyIS9qePqylrzDWrJLY=";

  ui = callPackage ./webui.nix { inherit version src; };

  postPatch =
    if enableWebui then
      ''
        cp -a ${ui} ui/dist
      ''
    else
      ''
        sed -i '/go:/d' ui/assets.go
      '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${version}"
  ];

  passthru.tests.rmfakecloud = nixosTests.rmfakecloud;

  meta = with lib; {
    description = "Host your own cloud for the Remarkable";
    homepage = "https://ddvk.github.io/rmfakecloud/";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [
      pacien
      martinetd
    ];
    mainProgram = "rmfakecloud";
  };
}
