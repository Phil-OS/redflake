{ pkgs }:

pkgs.python3Packages.buildPythonApplication {
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

  meta = {
    description = "Python collector for BloodHound Community Edition";
    homepage = "https://github.com/dirkjanm/BloodHound.py";
    license = pkgs.lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bloodhound-ce-python";
  };
}
