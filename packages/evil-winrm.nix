{ pkgs }:

pkgs.evil-winrm.override {
  bundlerEnv = args:
    let
      # winrm-fs requires csv, which Ruby 3.4 no longer includes by default.
      # Reuse the csv version and source hash from the locked Nixpkgs.
      csv = (import (pkgs.path + "/pkgs/top-level/ruby-packages.nix")).csv;
    in pkgs.bundlerEnv (args // {
      gemset = (import args.gemset) // { inherit csv; };
      gemfile = pkgs.writeText "evil-winrm-Gemfile" (
        builtins.readFile args.gemfile + "\ngem 'csv'\n"
      );
      lockfile = pkgs.writeText "evil-winrm-Gemfile.lock" (
        builtins.replaceStrings
          [ "\n    erubi (" "\nDEPENDENCIES\n" ]
          [ "\n    csv (${csv.version})\n    erubi (" "\nDEPENDENCIES\n  csv\n" ]
          (builtins.readFile args.lockfile)
      );
    });
}
