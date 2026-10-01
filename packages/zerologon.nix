{ pkgs }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.impacket ps.pycryptodomex ]);
in pkgs.stdenvNoCC.mkDerivation {
  pname = "zerologon";
  version = "unstable-6860f23";

  src = pkgs.fetchFromGitHub {
    owner = "dirkjanm";
    repo = "CVE-2020-1472";
    rev = "6860f23e015580ef3dcd168a1e1af61579342455";
    hash = "sha256-wA4dUPs36AsopW9myOMDK7Q4KXxDvfb06qC3vkjreog=";
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/zerologon"
    cp cve-2020-1472-exploit.py restorepassword.py "$out/share/zerologon/"
    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/zerologon-exploit" \
      --unset PYTHONPATH --unset PYTHONHOME --set PYTHONNOUSERSITE 1 \
      --add-flags "$out/share/zerologon/cve-2020-1472-exploit.py"
    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/zerologon-restore" \
      --unset PYTHONPATH --unset PYTHONHOME --set PYTHONNOUSERSITE 1 \
      --add-flags "$out/share/zerologon/restorepassword.py"
    runHook postInstall
  '';

  meta = {
    description = "Pinned top-level Zerologon scripts with isolated Python dependencies";
    homepage = "https://github.com/dirkjanm/CVE-2020-1472";
    platforms = [ "x86_64-linux" ];
    mainProgram = "zerologon-exploit";
  };
}
