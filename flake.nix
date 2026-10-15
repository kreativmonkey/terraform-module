{
  description = "Terraform module development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            opentofu
            nixfmt
          ];
          shellHook = ''echo "module shell: run just for available checks"'';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
