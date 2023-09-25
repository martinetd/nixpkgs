{ lib, runCommand, fetchFromGitHub, fetchpatch
, rustPlatform, protobuf }:

let
  pname = "ankisyncd";
  version = "1.1.4";

  # 23.10beta1
  ankirev = "2ab8aa002e1a03c2780eaae0c9e64803b2f5d821";

  ankiPatch = fetchpatch {
    name = "fix cargo vendor for rust-csv (anki)";
    # waiting on https://github.com/ankitects/rust-csv/pull/1
    url = "https://github.com/ankitects/anki/commit/eec4877b0e127e1f6672009e4d334e279c9f4be9.patch";
    hash = "sha256-ZDAW59VRPLeWWo5NYeE6ab44D5ekQzgHylzvfLgGvT8=";
  };

  # anki-sync-server-rs expects anki sources in the 'anki' folder
  # of its own source tree, with a patch applied (mostly to make
  # some modules public): prepare our own 'src' manually
  src = runCommand "anki-sync-server-rs-src" {
    src = fetchFromGitHub {
      owner = "ankicommunity";
      repo = "anki-sync-server-rs";
      rev = version;
      hash = "sha256-iL4lJJAV4SrNeRX3s0ZpJ//lrwoKjLsltlX4d2wP6O0=";
    };
    patches = [
      (fetchpatch {
        name = "update for anki 23.09";
        #https://github.com/ankicommunity/anki-sync-server-rs/pull/76
        url = "https://github.com/ankicommunity/anki-sync-server-rs/commit/7513494061035a5a9283b8a4197c9d433a3b787d.patch";
        hash = "sha256-g4Hjil1CSehLl5aixvL4/83n42GHjygYZ8KGeR3D7Zo=";
      })
      (fetchpatch {
        name = "fix cargo vendor for rust csv (ankisyncd)";
        # waiting on https://github.com/ankitects/rust-csv/pull/1
        url = "https://github.com/ankicommunity/anki-sync-server-rs/commit/222e6063c49087d65513f822ff9f9b2d70915897.patch";
        hash = "sha256-7GD5lo6lntYleghVlf+Nt9BUuzdhCHb1Q8YNE9rx4zs=";
      })
    ];
  } ''
    cp -r "$src/." "$out"
    chmod -R +w "$out"
    cp -r "${ankiSrc}" "$out/anki"
    chmod -R +w "$out/anki"
    # temp: apply patch manually
    cd "$out"
    chmod +w anki_patch scripts
    patchPhase
    # temp: nixos' patchPhase does not rename files, replace * with ${ankirev}
    patch -d "$out/anki" -Np1 < "$out/anki_patch/"*"_anki_rslib.patch"
    # temp: apply rust vendor fix manually until merged..
    patch -d "$out/anki" -Np1 < ${ankiPatch}
  '';

  # Note we do not use anki.src because the patch in ankisyncd's
  # sources expect a fixed version, so we pin it here.
  ankiSrc = fetchFromGitHub {
    owner = "ankitects";
    repo = "anki";
    rev = ankirev;
    hash = "sha256-huUG9Gn5Q2CRcChE6CM0jG/VkRcR0qaLkWg4FfL4OkE=";
    fetchSubmodules = true;
  };
in rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "burn-0.10.0" = "sha256-O3ci26D3bthO9qU0E7FhF5vZO3J0542BBgI4Vox2HEo=";
      "fsrs-0.1.0" = "sha256-FELkOQWrLfgPWx2FHNMPku59KVWYlpW77ShJdpIHUOE=";
      "percent-encoding-iri-2.2.0" = "sha256-kCBeS1PNExyJd4jWfDfctxq6iTdAq69jtxFQgCCQ8kQ=";
      "csv-1.1.6" = "sha256-/arebP7hd0Czo/pYViyoQufbqZHX6RtjJ9CEMkiDqak=";
    };
  };

  nativeBuildInputs = [ protobuf ];

  meta = with lib; {
    description = "Standalone unofficial anki sync server";
    homepage = "https://github.com/ankicommunity/anki-sync-server-rs";
    license = with licenses; [ agpl3Only ];
    maintainers = with maintainers; [ martinetd ];
  };
}
