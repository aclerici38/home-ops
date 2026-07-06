{ config, pkgs, lib, ... }:
{
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
      hash = lib.fakeHash;
    };
    globalConfig = ''
      acme_dns cloudflare {env.CF_API_TOKEN}
    '';
    virtualHosts."raphael.clerici.tech".extraConfig = ''
      reverse_proxy 127.0.0.1:8123
    '';

    virtualHosts."*.raphael.clerici.tech".extraConfig = ''
      tls {
        dns cloudflare {env.CF_API_TOKEN}
        resolvers 1.1.1.1
      }

      @frigate host frigate.raphael.clerici.tech
      handle @frigate {
        reverse_proxy https://127.0.0.1:8971
      }
      @jellyfin host jellyfin.raphael.clerici.tech
      handle @jellyfin {
        reverse_proxy 127.0.0.1:8096
      }
      @z2m host z2m.raphael.clerici.tech
      handle @z2m {
        reverse_proxy 127.0.0.1:8080
      }
      @syncthing host syncthing.raphael.clerici.tech
      handle @syncthing {
        reverse_proxy 127.0.0.1:8384
      }
    '';
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy.env".path;
}
