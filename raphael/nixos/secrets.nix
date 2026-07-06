{ config, ... }:
{
  sops.defaultSopsFile = ../secrets.sops.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets = {
    cloudflare-token = { };
    towonel-invite-token = { };
    # plaintext counterpart lives in sops as anthony-password
    anthony-password-hash = {
      neededForUsers = true;
    };
    mqtt-hass-password = {
      owner = "mosquitto";
      restartUnits = [ "mosquitto.service" ];
    };
    mqtt-z2m-password = {
      owner = "mosquitto";
      restartUnits = [ "mosquitto.service" ];
    };
    mqtt-frigate-password = {
      owner = "mosquitto";
      restartUnits = [ "mosquitto.service" ];
    };
  };

  sops.templates."caddy.env" = {
    # read by podman (root) at container start; injected into the caddy container.
    content = "CF_API_TOKEN=${config.sops.placeholder.cloudflare-token}";
    mode = "0400";
    restartUnits = [ "podman-caddy.service" ];
  };
  sops.templates."towonel.env" = {
    content = "TOWONEL_INVITE_TOKEN=${config.sops.placeholder.towonel-invite-token}";
    mode = "0400";
    restartUnits = [ "podman-towonel-agent.service" ];
  };
  sops.templates."z2m.env" = {
    content = ''
      ZIGBEE2MQTT_CONFIG_MQTT_USER=z2m
      ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD=${config.sops.placeholder.mqtt-z2m-password}
    '';
    mode = "0400";
    restartUnits = [ "podman-zigbee2mqtt.service" ];
  };
  sops.templates."frigate.env" = {
    content = "FRIGATE_MQTT_PASSWORD=${config.sops.placeholder.mqtt-frigate-password}";
    mode = "0400";
    restartUnits = [ "podman-frigate.service" ];
  };
}
