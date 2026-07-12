{ ... }:
{
  # Sonoff Zigbee Dongle Lite (EFR32MG21 / CP2102N) for zigbee2mqtt.
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{serial}=="046deb1ea4a3ef1187ab4abd61ce3355", GROUP="20", MODE="0660"
  '';
}
