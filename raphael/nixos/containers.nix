{ config, pkgs, ... }:
let
  tz = "America/Los_Angeles";
  nnp = "--security-opt=no-new-privileges";
  dropAll = "--cap-drop=ALL";

  mosquittoConf = pkgs.writeText "mosquitto.conf" ''
    listener 1883 0.0.0.0
    allow_anonymous true
    per_listener_settings false
    connection_messages false
    persistence true
    persistence_location /mosquitto/data
    autosave_interval 10
  '';
in
{
  # Data dirs pre-created with the uid the (non-root) containers run as.
  systemd.tmpfiles.rules = [
    "d /data/config/homeassistant 0750 0    0    -"
    "d /data/config/frigate       0750 0    0    -"
    "d /data/frigate              0750 0    0    -"
    "d /data/config/zigbee2mqtt   0750 1000 1000 -"
    "d /data/appdata/mosquitto    0750 1000 1000 -"
    "d /data/config/jellyfin      0750 1000 1000 -"
    "d /data/appdata/jellyfin-cache 0750 1000 1000 -"
    "d /data/config/syncthing     0750 1000 1000 -"
    "d /data/media                0755 1000 1000 -"
  ];

  virtualisation.oci-containers.containers = {
    mosquitto = {
      image = "public.ecr.aws/docker/library/eclipse-mosquitto:2.0.22@sha256:212f89e1eaeb2c322d6441b64396e3346026674db8fa9c27beac293405c32b3c";
      user = "1000:1000";
      extraOptions = [ nnp dropAll "--read-only" "--network=host" "--tmpfs=/tmp" ];
      volumes = [
        "${mosquittoConf}:/mosquitto/config/mosquitto.conf:ro"
        "/data/appdata/mosquitto:/mosquitto/data"
      ];
    };

    homeassistant = {
      image = "ghcr.io/home-assistant/home-assistant:2026.7.1@sha256:f73512ba4fe06bb4d57636fe3578d0820cdec46f81e8f837ab59e451662ff3cb";
      extraOptions = [ nnp dropAll "--network=host" ];
      volumes = [
        "/data/config/homeassistant:/config"
        "/run/dbus:/run/dbus:ro"
        "/etc/localtime:/etc/localtime:ro"
      ];
      environment.TZ = tz;
      dependsOn = [ "mosquitto" ];
    };

    zigbee2mqtt = {
      image = "ghcr.io/koenkk/zigbee2mqtt:2.12.1@sha256:80f7f04f72a99e4c4ef51ef7e98ee736edba6db0ecbb7abc626d0c4b0f1871f1";
      user = "1000:1000";
      extraOptions = [ nnp dropAll "--read-only" "--network=host" "--tmpfs=/tmp" ];
      volumes = [ "/data/config/zigbee2mqtt:/data" ];
      environment = {
        TZ = tz;
        ZIGBEE2MQTT_DATA = "/data";
        ZIGBEE2MQTT_CONFIG_SERIAL_PORT = "tcp://192.0.2.10:6638";
        ZIGBEE2MQTT_CONFIG_SERIAL_ADAPTER = "ember";
        ZIGBEE2MQTT_CONFIG_SERIAL_BAUDRATE = "115200";
        ZIGBEE2MQTT_CONFIG_MQTT_SERVER = "mqtt://127.0.0.1:1883";
        ZIGBEE2MQTT_CONFIG_MQTT_VERSION = "5";
        ZIGBEE2MQTT_CONFIG_MQTT_BASE_TOPIC = "zigbee2mqtt";
        ZIGBEE2MQTT_CONFIG_FRONTEND_PORT = "8080";
        ZIGBEE2MQTT_CONFIG_FRONTEND_URL = "https://z2m.raphael.clerici.tech";
        ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_ENABLED = "true";
        ZIGBEE2MQTT_CONFIG_AVAILABILITY_ENABLED = "true";
        ZIGBEE2MQTT_CONFIG_ADVANCED_LOG_OUTPUT = ''["console"]'';
        ZIGBEE2MQTT_CONFIG_ADVANCED_LAST_SEEN = "ISO_8601";
      };
      dependsOn = [ "mosquitto" ];
    };

    frigate = {
      image = "ghcr.io/blakeblackshear/frigate:0.17.2@sha256:d4351369984d4a9e2a49ac59736f6490856a7ea11f7790040746d21496967010";
      extraOptions = [
        nnp
        dropAll
        "--cap-add=CHOWN"
        "--cap-add=SETUID"
        "--cap-add=SETGID"
        "--cap-add=FOWNER"
        "--cap-add=DAC_OVERRIDE"
        "--cap-add=PERFMON"
        "--network=host"
        "--device=/dev/dri/renderD128"
        "--shm-size=256m"
        "--tmpfs=/tmp/cache:size=5g"
      ];
      volumes = [
        "/data/config/frigate:/config"
        "/data/frigate:/media/frigate"
        "/etc/localtime:/etc/localtime:ro"
      ];
      environment = {
        TZ = tz;
        S6_READ_ONLY_ROOT = "1";
        HF_HOME = "/tmp";
      };
      dependsOn = [ "mosquitto" ];
    };

    jellyfin = {
      image = "ghcr.io/jellyfin/jellyfin:10.11.11@sha256:45f648c382a0c8b552582fcea40e95cb17c5d475473a891cba0eb7523fb92112";
      user = "1000:1000";
      extraOptions = [ nnp dropAll "--read-only" "--device=/dev/dri/renderD128" "--tmpfs=/tmp" ];
      ports = [ "127.0.0.1:8096:8096" ];
      volumes = [
        "/data/config/jellyfin:/config"
        "/data/appdata/jellyfin-cache:/cache"
        "/data/media:/media:ro"
      ];
      environment.TZ = tz;
    };

    syncthing = {
      image = "docker.io/syncthing/syncthing:1.30.0@sha256:74eeedb08d4912763055594f8bd98bfc039f3bc504b6cd2c2adc8294111c1251";
      user = "1000:1000";
      extraOptions = [ nnp dropAll "--read-only" "--tmpfs=/tmp" ];
      ports = [
        "127.0.0.1:8384:8384"
        "22000:22000/tcp"
        "22000:22000/udp"
        "21027:21027/udp"
      ];
      volumes = [
        "/data/config/syncthing:/var/syncthing"
        "/data/media:/var/syncthing/media"
      ];
      environment.TZ = tz;
    };

    towonel-agent = {
      image = "codeberg.org/towonel/towonel-agent:1.0.1@sha256:bdd7d6cb166bf2f985ebc98b03c866c65300aa0432f0a43b2fe44c3e8e5dad44";
      extraOptions = [ nnp dropAll "--read-only" "--network=host" "--tmpfs=/tmp" ];
      environmentFiles = [ config.sops.templates."towonel.env".path ];
      environment = {
        RUST_LOG = "info";
        TOWONEL_AGENT_HEALTH_LISTEN_ADDR = "127.0.0.1:9090";
        TOWONEL_AGENT_SERVICES = ''[{"hostname":"hass.raphael.clerici.tech","origin":"127.0.0.1:8123"}]'';
      };
    };
  };
}
