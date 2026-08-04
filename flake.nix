{
  description = "CHANGEME";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting";
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    let
      sas = set-and-setting;
      supportedSystems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
      fragments = [ "base" "nix" "shell" "ascii" "markdown" "yaml" ];
    in {
      packages = forAllSystems (pkgs: {
        setting = (sas.lib.mkSetting { inherit pkgs; }).materialized;
        default = pkgs.writeShellApplication {
          name = "lefthook-taplo";
          runtimeInputs = [ pkgs.taplo ];
          text = builtins.readFile ./lefthook-taplo.sh;
        };
      });

      devShells = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fragments = [ "base" "nix" "shell" "ascii" "markdown" "yaml" ];
          sas = set-and-setting;
        in
        let
          mat = sas.lib.materializationFor { inherit pkgs fragments; };
          sys = pkgs.stdenv.hostPlatform.system;
        in
        sas.lib.mkDevShells {
          inherit pkgs;
          basePackages = mat.packages ++ [ self.packages.${sys}.default ];
          defaultShellHook = ''
            ${self.packages.${sys}.setting}/bin/sync-setting .
            cp -f ${mat.files}/lefthook.yml lefthook.yml
          '';
        }
      );

      checks = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fragments = [ "base" "nix" "shell" "ascii" "markdown" "yaml" ];
          sas = set-and-setting;
        in
        (sas.lib.checksFor {
          inherit pkgs fragments;
          src = ./.;
        })
        // {
          dep-graph = sas.lib.mkDepGraphCheck {
            inherit pkgs;
            projectRoot = ./.;
          };
          default = pkgs.runCommand "checks" { } "touch $out";
        }
      );

      apps = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fragments = [ "base" "nix" "shell" "ascii" "markdown" "yaml" ];
          sas = set-and-setting;
        in
        let
          mat = sas.lib.materializationFor { inherit pkgs fragments; };
        in
        {
          confirm = {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "confirm";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.diffutils
                  pkgs.findutils
                  pkgs.gawk
                  pkgs.git
                  pkgs.gnugrep
                ]
                ++ mat.packages;
                text = ''
                  export FRAGMENTS_DIR="${set-and-setting}/setting/integrations/lefthook"
                  export ASSEMBLE_SCRIPT="${set-and-setting}/setting/lib/assemble-lefthook.sh"
                  export DETECT_SCRIPT="${set-and-setting}/setting/lib/detect-fragments.sh"
                  export SETTING_SRC="${self.packages.${pkgs.stdenv.hostPlatform.system}.setting}"
                  export CONFIRM_SCRIPT="${set-and-setting}/lib/confirm.sh"
                  export CONFIRM_REV="${set-and-setting.rev or "unknown"}"
                  bash "$CONFIRM_SCRIPT"
                '';
              }
            }/bin/confirm";
          };
        }
      );
    };
}
