{ ... }:
{
  # Sonoff Zigbee 3.0 USB Dongle Plus V2 (CC2652 / CP2102N) for zigbee2mqtt.
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{serial}=="d4f0088f4c1fef119b9450d0639e525b", GROUP="20", MODE="0660"
  '';
}
