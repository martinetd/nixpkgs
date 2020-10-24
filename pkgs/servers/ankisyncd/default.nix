{ lib
, fetchFromGitHub
, python3
, anki
}:

python3.pkgs.buildPythonApplication rec {
  pname = "ankisyncd";
  date = "20200905";
  rev = "68776c21b5c506505902b98957bf3ccba139cabd";
  version = "${date}-${rev}";
  src = fetchFromGitHub {
    owner = "ankicommunity";
    repo = "anki-sync-server";
    rev = rev;
    sha256 = "19br2ba2jarmjd01prlph78qqvy6f5rbpq5ag78vz3x70k7z9yiq";
  };
  format = "other";

  patchPhase = ''
    rm -f Makefile
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/${python3.sitePackages}

    cp -r src/ankisyncd src/utils src/ankisyncd.conf $out/${python3.sitePackages}
    mkdir $out/share
    cp src/ankisyncctl.py $out/share/

    runHook postInstall
  '';

  fixupPhase = ''
    PYTHONPATH="$PYTHONPATH:$out/${python3.sitePackages}:${anki}"

    makeWrapper "${python3.interpreter}" "$out/bin/ankisyncd" \
          --set PYTHONPATH $PYTHONPATH \
          --add-flags "-m ankisyncd"

    makeWrapper "${python3.interpreter}" "$out/bin/ankisyncctl" \
          --set PYTHONPATH $PYTHONPATH \
          --add-flags "$out/share/ankisyncctl.py"
  '';

  checkInputs = with python3.pkgs; [
    pytest
    webtest
  ];

  buildInputs = [ ];

  propagatedBuildInputs = [ anki ];

  checkPhase = ''
    # Exclude tests that require sqlite's sqldiff command, since
    # it isn't yet packaged for NixOS, although 2 PRs exist:
    # - https://github.com/NixOS/nixpkgs/pull/69112
    # - https://github.com/NixOS/nixpkgs/pull/75784
    # Once this is merged, these tests can be run as well.
    pytest --ignore tests/test_web_media.py tests/
  '';

  meta = with lib; {
    description = "Self-hosted Anki sync server";
    maintainers = with maintainers; [ matt-snider ];
    homepage = "https://github.com/tsudoko/anki-sync-server";
    license = licenses.agpl3;
    platforms = platforms.linux;
  };
}
