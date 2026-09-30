{
  description = "Red teaming toolkit, for professional use only. With great power comes great responsibility.";

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
