{
  description = "MLVU";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = { self, nixpkgs, ... }:
  let
    pkgs = nixpkgs.legacyPackages.${system};
    system = "x86_64-linux";
  in {
    devShells."${system}".default = pkgs.mkShell {
      packages = with pkgs; [
        typst-lsp
        typst
        typst-live
        pdf2svg
      ];
      TYPST_FONT_PATHS = "./OTF";
    };
  };
}