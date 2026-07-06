{ config, ... }:
{
  services.mosquitto = {
    enable = true;
    persistence = false;
    listeners = [
      {
        port = 1883;
        settings.allow_anonymous = false;
        users = {
          hass = {
            acl = [ "readwrite #" ];
            passwordFile = config.sops.secrets.mqtt-hass-password.path;
          };
          z2m = {
            acl = [ "readwrite #" ];
            passwordFile = config.sops.secrets.mqtt-z2m-password.path;
          };
          frigate = {
            acl = [ "readwrite #" ];
            passwordFile = config.sops.secrets.mqtt-frigate-password.path;
          };
        };
      }
    ];
  };

  systemd.services.podman-homeassistant = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };
  systemd.services.podman-zigbee2mqtt = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };
  systemd.services.podman-frigate = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };
}
