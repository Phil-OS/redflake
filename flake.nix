{
  description = "Reproducible red teaming toolkit for professional use";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      shellPackage = import ./packages/shell.nix { inherit pkgs; };
      groups = {
        core = with pkgs; [
          git curl jq ripgrep fzf tmux vim
          shellPackage zsh neovim python3Packages.pygments less man-db
        ];
        network = with pkgs; [ nmap freerdp ligolo-ng proxychains sshuttle ];
        web = with pkgs; [ dirb ];
        ad = with pkgs; [ netexec responder kerbrute evil-winrm ];
        credentials = with pkgs; [ thc-hydra hashcat john ];
        framework = with pkgs; [ metasploit ];
      };
      python = pkgs.python3.withPackages (ps: with ps; [ impacket pwntools certipy-ad ]);
      profiles = {
        core = groups.core;
        web = groups.core ++ groups.web ++ [ pkgs.nmap ];
        # Keep toolkit Python ahead of interpreters propagated by CLI dependencies.
        ad = [ python ] ++ groups.core ++ groups.ad ++ groups.network;
        full = [ python ] ++ pkgs.lib.concatLists (builtins.attrValues groups);
      };
      shells = builtins.mapAttrs (name: packages: pkgs.mkShell {
        name = "redTool-${name}";
        inherit packages;
        REDFLAKE_PROFILE = name;
        shellHook = ''
          case $- in
            *i*) exec ${shellPackage}/bin/redflake-zsh ;;
          esac
        '';
      }) profiles;
    in {
      devShells.${system} = shells // { default = shells.full; };
      packages.${system}.redflake-shell = shellPackage;
      checks.${system} = {
        shell = pkgs.runCommand "redflake-shell-checks" {
          nativeBuildInputs = [ pkgs.zsh pkgs.python3 ];
        } ''
          zsh -n ${shellPackage}/share/redflake/zsh/.zshrc
          python3 -B ${./tests/check_zsh.py} --launcher ${shellPackage}/bin/redflake-zsh
          touch "$out"
        '';
        scripts = pkgs.runCommand "redflake-script-checks" {
          nativeBuildInputs = [ pkgs.bash pkgs.shellcheck pkgs.python3 ];
        } ''
          cd ${./.}
          bash -n quickconfig.sh scripts/smoke.sh
          shellcheck quickconfig.sh scripts/smoke.sh
          python3 -B -m unittest discover -s tests -v
          touch "$out"
        '';
      };
    };
}
