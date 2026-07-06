{ config, ... }:
# sops-nix: age key = the host's SSH key (generated at install), so there's no
# separate key to place. Bootstrap note in README: secrets.sops.yaml is currently
# encrypted to the repo age key; after first boot, add the host key as a recipient
# (ssh-to-age /etc/ssh/ssh_host_ed25519_key.pub) and `sops updatekeys`.
{
  sops.defaultSopsFile = ../secrets.sops.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt"; # bootstrap: repo age key lives here

  sops.secrets = {
    cloudflare-token = { };
    towonel-invite-token = { };
    # read by the mosquitto module's preStart (runs as the mosquitto user) to
    # build its hashed password_file; hass's is also what you type into HA's
    # MQTT integration UI once
    mqtt-hass-password = { owner = "mosquitto"; restartUnits = [ "mosquitto.service" ]; };
    mqtt-z2m-password = { owner = "mosquitto"; restartUnits = [ "mosquitto.service" ]; };
    mqtt-frigate-password = { owner = "mosquitto"; restartUnits = [ "mosquitto.service" ]; };
  };

  # restartUnits: rotating a secret re-renders the template and bounces the
  # consuming unit on the next switch, instead of leaving it on stale creds
  sops.templates."caddy.env" = {
    content = "CF_API_TOKEN=${config.sops.placeholder.cloudflare-token}";
    owner = "caddy";
    mode = "0400";
    restartUnits = [ "caddy.service" ];
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
