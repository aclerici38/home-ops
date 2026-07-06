{ config, pkgs, lib, ... }:
# Single LAN-facing HTTP surface. One wildcard cert *.raphael.clerici.tech via
# Cloudflare DNS-01 (works behind NAT, no inbound), routed per-subdomain.
# CF_API_TOKEN comes from /run/secrets/caddy.env (populated by the secrets manager).
{
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
      hash = lib.fakeHash; # <-- first build fails and prints the real hash; paste it here
    };
    globalConfig = ''
      acme_dns cloudflare {env.CF_API_TOKEN}
    '';
    virtualHosts."*.raphael.clerici.tech".extraConfig = ''
      tls {
        dns cloudflare {env.CF_API_TOKEN}
        resolvers 1.1.1.1
      }

      @ha host ha.raphael.clerici.tech
      handle @ha {
        reverse_proxy 127.0.0.1:8123
      }
      @frigate host frigate.raphael.clerici.tech
      handle @frigate {
        reverse_proxy https://127.0.0.1:8971 {
          transport http {
            tls_insecure_skip_verify
          }
        }
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
