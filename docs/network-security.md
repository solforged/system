# Local network security

## Hyperion

`hosts/hyperion/firewall.nix` enables the macOS application firewall while
preserving the current AirPlay Receiver and remote-access allowances. Built-in
and downloaded signed software remain automatically allowed; block-all and
stealth modes stay off. Existing per-application rules are retained, not reset.
This first phase is not a strict incoming allow-list.

After applying a reviewed build, verify firewall state and its application list,
AirPlay to the Mac, Rex from a paired device, and SSH over Tailscale. Check that
ordinary LAN SSH login is still denied. A build or sandbox check alone cannot
verify live macOS firewall behavior or device connectivity.

Before disabling automatic allowances for downloaded signed apps, establish
and test explicit exceptions for Rex Server's helper executable and Tailscale's
installed networking extension. Allowing only the outer app bundles is not
enough. Review existing interpreter-wide and unused sharing allowances as a
separate change rather than silently carrying them into a strict policy.

Built-in services remain reachable when their own sharing settings permit it.
This is not a source-address firewall or an IoT isolation boundary. SSH has
separate tailnet-only login restrictions; see [SSH](keys/ssh.md).

## IoT containment

A separate Deco IoT SSID does not create a separate security zone. Device
Isolation blocks communication between isolated and non-isolated clients, so
putting a locally controlled accessory behind it can break Home Assistant.
Tailscale access policy does not restrict traffic sent directly over the LAN.

Accessories controlled locally through Matter or HomeKit can be candidates for
internet denial while retaining LAN access. Test one noncritical accessory at a
time, including IPv4/IPv6 enforcement, persistence after reconnecting, local
control and a deliberate firmware-update path. DNS filtering is not internet
denial, and internet denial does not prevent lateral movement on the LAN.

Stronger containment needs a routed boundary with explicit controller access.
Keep Matter devices, their controller and required Thread border routers on the
same automation network where possible. Trusted clients need narrowly scoped
access to Home Assistant's HomeKit bridge and discovery. Deny unsolicited
access from automation devices into trusted computers and storage, and treat
Home Assistant itself as exposed rather than giving it unrestricted access.
