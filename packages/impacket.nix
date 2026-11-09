{ pkgs }:

let
  impacket = pkgs.python3Packages.impacket;
in pkgs.runCommand "impacket-tools-${impacket.version}" {
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta = {
    description = "Impacket suite with isolated impacket-* command wrappers";
    inherit (impacket.meta) homepage license;
    platforms = [ "x86_64-linux" ];
    mainProgram = "impacket";
  };
} ''
  mkdir -p "$out/bin"
  for script in ${impacket}/bin/*.py; do
    name=$(basename "$script" .py)
    makeWrapper "$script" "$out/bin/impacket-$name" \
      --unset PYTHONPATH --unset PYTHONHOME \
      --unset NIX_PYTHONPATH --unset NIX_PYTHONPREFIX \
      --unset NIX_PYTHONEXECUTABLE --set PYTHONNOUSERSITE 1
  done

  cat > "$out/bin/impacket" <<'EOF'
  #!${pkgs.runtimeShell}
  if (( $# > 1 )) || [[ $# == 1 && "$1" != -h && "$1" != --help ]]; then
    printf 'Usage: impacket [-h|--help]\n' >&2
    exit 2
  fi
  printf 'Usage: impacket [-h|--help]\n\nAvailable Impacket commands:\n'
  for command in @bin@/impacket-*; do
    printf '%s\n' "''${command##*/}"
  done
  printf '\nRun a command with -h to see its options.\n'
  EOF
  substituteInPlace "$out/bin/impacket" --replace-fail '@bin@' "$out/bin"
  chmod +x "$out/bin/impacket"
''
