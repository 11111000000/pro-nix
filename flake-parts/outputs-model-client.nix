{ pkgs, lib, python3, ... }:

let
  inherit (pkgs) stdenv fetchurl buildPythonPackage python3Packages;
in

{
  model-client = buildPythonPackage rec {
    pname = "model-client";
    version = "0.1.0";
    src = ./.;
    propagatedBuildInputs = with python3Packages; [ fastapi uvicorn requests ];
    doCheck = false;
    meta = with lib; {
      description = "Simple model client proxy for agents";
      license = licenses.mit;
    };
  };
}
