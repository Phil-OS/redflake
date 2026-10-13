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
      bloodhoundCePackage = import ./packages/bloodhound-ce-python.nix { inherit pkgs; };
      zerologonPackage = import ./packages/zerologon.nix { inherit pkgs; };
      # NetExec uses Python 3.12 in the locked Nixpkgs; the toolkit uses 3.13.
      # Keep its packaged dependencies ahead of any inherited Python environment.
      netexecPackage = pkgs.netexec.overrideAttrs (old: {
        makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
          "--unset PYTHONPATH" "--unset PYTHONHOME"
          "--unset NIX_PYTHONPATH" "--unset NIX_PYTHONPREFIX"
          "--unset NIX_PYTHONEXECUTABLE"
        ];
      });
      groups = {
        core = with pkgs; [
          git curl jq ripgrep fzf tmux vim
          shellPackage zsh neovim python3Packages.pygments less man-db
          openssh nmap dig
        ];
        network = with pkgs; [ freerdp ligolo-ng proxychains sshuttle ];
        web = with pkgs; [ dirb ffuf sqlmap ];
        ad = with pkgs; [
          netexecPackage responder kerbrute evil-winrm
          bloodhoundCePackage (python3Packages.toPythonApplication python3Packages.bloodyad)
          ldapdomaindump enum4linux-ng krb5 openldap samba
          zerologonPackage
        ];
        inspection = with pkgs; [ tcpdump wireshark-cli ];
        assets = with pkgs; [ seclists ];
        gui = with pkgs; [ burpsuite ];
        credentials = with pkgs; [ thc-hydra hashcat john ];
        framework = with pkgs; [ metasploit ];
      };
      python = pkgs.python3.withPackages (ps: with ps; [ impacket pwntools certipy-ad ]);
      profiles = {
        core = groups.core;
        web = groups.core ++ groups.web ++ groups.assets;
        gui = groups.core ++ groups.web ++ groups.assets ++ groups.gui;
        # Keep toolkit Python ahead of interpreters propagated by CLI dependencies.
        ad = [ python ] ++ groups.core ++ groups.ad ++ groups.network ++ groups.inspection ++ groups.assets;
        full = [ python ] ++ pkgs.lib.concatLists (builtins.attrValues (builtins.removeAttrs groups [ "gui" ]));
      };
      shells = builtins.mapAttrs (name: packages: pkgs.mkShell ({
        name = "redTool-${name}";
        inherit packages;
        REDFLAKE_PROFILE = name;
        shellHook = ''
          case $- in
            *i*) exec ${shellPackage}/bin/redflake-zsh ;;
          esac
        '';
      } // pkgs.lib.optionalAttrs (name != "core") {
        REDFLAKE_SECLISTS = "${pkgs.seclists}/share/wordlists/seclists";
      })) profiles;
    in {
      devShells.${system} = shells // { default = shells.full; };
      packages.${system} = {
        redflake-shell = shellPackage;
        bloodhound-ce-python = bloodhoundCePackage;
        zerologon = zerologonPackage;
      };
      checks.${system}.netexec = pkgs.runCommand "netexec-smb-startup-check" {
        nativeBuildInputs = [ netexecPackage pkgs.coreutils ];
      } ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        # Empty local targets load SMB imports without connecting to a host.
        : > "$TMPDIR/targets"
        for command in nxc netexec NetExec; do
          timeout 30 "$command" smb "$TMPDIR/targets"
          PYTHONPATH="${python}/${pkgs.python3.sitePackages}" \
            timeout 30 "$command" smb "$TMPDIR/targets"
          PYTHONHOME="$TMPDIR/missing-python" \
            NIX_PYTHONPATH="${python}/${pkgs.python3.sitePackages}" \
            NIX_PYTHONPREFIX="${python}" \
            NIX_PYTHONEXECUTABLE="${python}/bin/python3" \
            timeout 30 "$command" smb "$TMPDIR/targets"
        done
        touch "$out"
      '';
    };
}
