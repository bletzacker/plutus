let
  # iohk-nix can be overridden for debugging purposes by setting
  # NIX_PATH=iohk_nix=/path/to/iohk-nix
  iohkNix = import (
    let try = builtins.tryEval <iohk_nix>;
    in if try.success
    then builtins.trace "using host <iohk_nix>" try.value
    else
      let
        spec = builtins.fromJSON (builtins.readFile ./iohk-nix.json);
      in builtins.fetchTarball {
        url = "${spec.url}/archive/${spec.rev}.tar.gz";
        inherit (spec) sha256;
      }) {};

  # nixpkgs can be overridden for debugging purposes by setting
  # NIX_PATH=custom_nixpkgs=/path/to/nixpkgs
  pkgs = iohkNix.pkgs;
  lib = pkgs.lib;
  getPackages = iohkNix.getPackages;

  # List of all plutus pkgs. This is used for `isPlutus` filter and `mapTestOn`
  plutusPkgList = [
    "language-plutus-core"
    "plutus-core-interpreter"
    "plutus-exe"
    "plutus-ir"
    "plutus-tx"
    "plutus-tx-plugin"
    "plutus-use-cases"
    "wallet-api"
    "bazel-runfiles"
  ];


  isPlutus = name: builtins.elem name plutusPkgList;

  withDevTools = env: env.overrideAttrs (attrs: { nativeBuildInputs = attrs.nativeBuildInputs ++ [ pkgs.cabal-install pkgs.haskellPackages.ghcid ]; });
in lib // {
  inherit getPackages iohkNix isPlutus plutusPkgList withDevTools pkgs;
}
