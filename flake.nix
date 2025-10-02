{
  description = "Red teaming toolkit";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05"; };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in with pkgs; {
      devShells.${system}.default = mkShell {
        name = "redTool";

        buildInputs = [
          dirb
          thc-hydra
          metasploit
          nmap
          hashcat
          wordlists
          netexec
          responder
          kerbrute
          john
          evil-winrm
          freerdp
          ligolo-ng
          proxychains
          vim
          sshuttle
          (python3.withPackages
            (ps: with ps; [ impacket pwntools certipy-ad ]))
        ];
      };
    };
}
