{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
  let 
    system  = "x86_64-linux"; 
    pkgs    = nixpkgs.legacyPackages.${system};
    pname   = "cursor"; 
    version = "0.1";
  in {
    packages.x86_64-linux.cursor = nixpkgs.legacyPackages.x86_64-linux.stdenv.mkDerivation {
      inherit pname;
      version = "0.1";

      src = ./.; 
      
      buildInputs = [pkgs.gcc pkgs.ncurses]; 

      buildPhase = '' 
        make 
      '';

      installPhase = '' 
        mkdir -p $out/bin
        cp ${pname} $out/bin
      '';
    };
    defaultPackage.${system} = self.packages.${system}.${pname}; 
    apps.x86_64-linux.default = {
      type = "app"; 
      program = "${self.packages.x86_64-linux.cursor}/bin/cursor";
    };
  };
}
