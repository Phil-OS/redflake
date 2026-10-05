{ pkgs }:

let
  runtimePath = pkgs.lib.makeBinPath (with pkgs; [
    zsh git vim neovim python3Packages.pygments less man-db
    coreutils findutils gnugrep gnused gawk procps
  ]);
in pkgs.stdenvNoCC.mkDerivation {
  pname = "redflake-shell";
  version = "1.0";
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/redflake/zsh/custom"
    cp ${../shell/palette.zsh} "$out/share/redflake/zsh/palette.zsh"
    cp ${../shell/prompt.zsh} "$out/share/redflake/zsh/prompt.zsh"
    substitute ${../shell/zshrc} "$out/share/redflake/zsh/.zshrc" \
      --replace-fail '@ohMyZsh@' '${pkgs.oh-my-zsh}/share/oh-my-zsh' \
      --replace-fail '@syntaxHighlighting@' '${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
    cat > "$out/bin/redflake-zsh" <<EOF
#!${pkgs.runtimeShell}
export ZDOTDIR="$out/share/redflake/zsh"
export PATH="${runtimePath}:\$PATH"
exec ${pkgs.zsh}/bin/zsh "\$@"
EOF
    chmod +x "$out/bin/redflake-zsh"
    runHook postInstall
  '';
  meta = {
    description = "Portable redflake Oh My Zsh configuration";
    platforms = [ "x86_64-linux" ];
    mainProgram = "redflake-zsh";
  };
}
