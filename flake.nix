{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    flake-utils = {
      url = "github:numtide/flake-utils/v1.0.0";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system; #overlays;
          config.allowUnfree = false;
        };
      in
      {
        packages.devenv-up = self.devShells.${system}.default.config.procfileScript;

        dotenv.enable = false;

        devShells = {
          default = devenv.lib.mkShell {
            inherit pkgs inputs;
            modules = [
                {
                  packages = with pkgs; [
                    sqls
                    postgresql_16
                  ];

                  services.postgres = {
                    enable = true;
                    package = pkgs.postgresql_16;

                    initdbArgs = [
                      "--locale=C"
                      "--encoding=UTF8"
                    ]; # --show

                    extensions = ext: [
                      ext.periods
                    ];

                    initialDatabases = [
                      {
                        name = "message_store";
                        schema = ./events.sql;
                      }
                    ];

                    port = 5432;
                    listen_addresses = "127.0.0.1";

                    settings = { };

                    initialScript = ''
                      CREATE USER admin WITH PASSWORD 'admin' SUPERUSER;
                      ALTER DATABASE message_store OWNER TO admin;
                    '';
                  };
                }
            ];
          };
        };

        # nix fmt
        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
