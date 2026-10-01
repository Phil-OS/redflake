{ pkgs }:

let
  python = pkgs.python3;
in pkgs.python3Packages.buildPythonApplication {
  pname = "bloodhound-ce";
  version = "1.9.1";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "bloodhound_ce";
    version = "1.9.1";
    hash = "sha256-CD3z3DrZmO3P+Ptj/dj1tGSqtf2sjgXMmztlICEPeas=";
  };

  build-system = [ pkgs.python3Packages.setuptools ];
  dependencies = with pkgs.python3Packages; [
    dnspython impacket ldap3 pyasn1 pycryptodome
  ];

  # The packaged script supplies its own imports through the Nix Python wrapper.
  makeWrapperArgs = [ "--unset PYTHONPATH" "--unset PYTHONHOME" ];
  pythonImportsCheck = [ "bloodhound" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$(mktemp -d)"
    cd "$HOME"
    PYTHONNOUSERSITE=1 \
      PYTHONPATH="$out/${python.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}" \
      ${python.interpreter} -c 'import importlib.metadata; assert importlib.metadata.version("bloodhound-ce") == "1.9.1"'
    timeout 15 "$out/bin/bloodhound-ce-python" -h > help.txt
    grep -qi 'usage:' help.txt
    test ! -e "$out/bin/bloodhound-python"

    mkdir poison
    echo 'raise RuntimeError("inherited PYTHONPATH was loaded")' > poison/bloodhound.py
    PYTHONPATH="$HOME/poison" timeout 15 "$out/bin/bloodhound-ce-python" -h > poisoned-help.txt
    grep -qi 'usage:' poisoned-help.txt
    runHook postInstallCheck
  '';

  meta = {
    description = "Python collector for BloodHound Community Edition";
    homepage = "https://github.com/dirkjanm/BloodHound.py";
    license = pkgs.lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bloodhound-ce-python";
  };
}
