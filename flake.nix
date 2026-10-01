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
      groups = {
        core = with pkgs; [ git curl jq ripgrep fzf tmux vim ];
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
        ad = groups.core ++ groups.ad ++ groups.network ++ [ python ];
        full = pkgs.lib.concatLists (builtins.attrValues groups) ++ [ python ];
      };
      shells = builtins.mapAttrs (name: packages: pkgs.mkShell {
        name = "redTool-${name}";
        inherit packages;
        REDFLAKE_PROFILE = name;
      }) profiles;
    in {
      devShells.${system} = shells // { default = shells.full; };
      checks.${system}.scripts = pkgs.runCommand "redflake-script-checks" {
        nativeBuildInputs = [ pkgs.bash pkgs.shellcheck pkgs.python3 ];
      } ''
        cd ${./.}
        bash -n quickconfig.sh scripts/smoke.sh
        shellcheck quickconfig.sh scripts/smoke.sh
        python3 -B -m unittest discover -s tests -v
        touch "$out"
      '';
    };
}
