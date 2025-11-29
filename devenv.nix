{ pkgs, lib, config, inputs, ... }:{

  cachix.enable = false;

  env = {
    LD_LIBRARY_PATH = "${config.devenv.profile}/lib";
    RUBOCOP_CACHE_ROOT = "${config.devenv.state}/rubocop_cache";
  };

  packages = with pkgs; [
    git
    libyaml
    sqlite-interactive
    bashInteractive
    openssl
    curl
    libxml2
    libxslt
    libffi
    docker
  ];

  languages.ruby.enable = true;
  languages.ruby.versionFile = ./.ruby-version;
}
