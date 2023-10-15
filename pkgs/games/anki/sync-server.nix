{ lib
, rustPlatform
, anki

, openssl
, pkg-config
, protobuf
}:

rustPlatform.buildRustPackage {
  pname = "anki-sync-server";
  inherit (anki) version src cargoLock;

  # only build sync server
  cargoBuildFlags = [
    "--bin"
    "anki-sync-server"
  ];

  nativeBuildInputs = [ protobuf pkg-config ];
  env.PROTOC = lib.getExe protobuf;
  buildInputs = [ openssl ];

  meta = with lib; {
    description = "Standalone official anki sync server";
    homepage = "https://apps.ankiweb.net";
    license = with licenses; [ agpl3Plus ];
    maintainers = with maintainers; [ martinetd ];
    mainProgram = "anki-sync-server";
  };
}
