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
      impacketPackage = import ./packages/impacket.nix { inherit pkgs; };
      evilWinrmPackage = import ./packages/evil-winrm.nix { inherit pkgs; };
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
          netexecPackage impacketPackage responder kerbrute evilWinrmPackage
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
        impacket = impacketPackage;
        evil-winrm = evilWinrmPackage;
        zerologon = zerologonPackage;
      };
      checks.${system} = {
        evil-winrm = pkgs.runCommand "evil-winrm-startup-check" {
          nativeBuildInputs = [ evilWinrmPackage pkgs.coreutils pkgs.gnugrep ];
        } ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          # Help loads winrm-fs and its Ruby dependencies without a remote target.
          for option in -h --help; do
            timeout 15 evil-winrm "$option" > "$TMPDIR/help"
            grep -F 'Usage: evil-winrm' "$TMPDIR/help"
          done
          # Nixpkgs supplies the bundled Ruby as evil-winrm's build input.
          # Validate that the generated Gemfile and lockfile also work in Bundler.
          timeout 15 ${(builtins.head evilWinrmPackage.buildInputs)}/bin/ruby \
            -rbundler/setup -rcsv -rwinrm-fs -e 'exit'
          touch "$out"
        '';
        bloodhound-ce-python = bloodhoundCePackage;
        zerologon = zerologonPackage;
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
        netexec = pkgs.runCommand "netexec-smb-startup-check" {
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
    };
}
