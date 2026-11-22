# Sennheiser EW-DX Monitor for Q-SYS

This separate, monitoring-only plugin targets EW-DX EM 2, EM 2 Dante and EM 4
Dante receivers.

**Status: tested.** The SSCv1 and SSCv2 implementations have been tested in
Q-SYS Designer and with physical receiver hardware. Compatibility may vary by
model and firmware.

## Setup

1. Import [Sennheiser-ew-dx.qplug](Sennheiser-ew-dx.qplug), add one instance
   per receiver, and select the receiver **Model** in its Designer properties.
   The model determines whether two or four channels are generated; the
   plugin does not automatically verify the model.
2. Load or emulate the design. On **Configuration**, enter the receiver's
   IPv4 address and select **SSCv2** or **SSCv1**. Emulation needs a real
   reachable receiver; it does not simulate one.
3. For SSCv2, enable **Secure** third-party access on the receiver in
   Sennheiser Control Cockpit and enter the configured third-party password.
   The API username is `api`, not the device-access username. Third-party
   access is disabled by default on firmware 4 and later.
4. For SSCv1, select **Legacy** third-party access on firmware 4 or later.
   Earlier firmware uses the legacy protocol. SSCv1 is unauthenticated and
   unencrypted; use an appropriately isolated control network.

When updating an existing design, load the newer plugin version in Designer
and check the generated controls and UCI links.

The password is displayed in the configuration interface and may be
accessible to designers and stored in the Q-SYS design. The plugin does not
intentionally log it. SSCv2 uses HTTPS with Q-SYS `HttpClient` defaults;
certificate trust depends on the target system and receiver. No fallback to
SSCv1 is attempted. Check **Status** and **Last Error** if authentication or
HTTPS fails.

## Monitoring

The monitoring page shows each channel in a column with numeric readouts and
RF strength, link quality, audio level, and battery meters. Each channel
exposes text output pins and monitoring fields for name,
frequency (MHz), RF strength (dBm), RF quality (%), active antenna, audio
level (dBFS), receiver output and transmitter mute, transmitter battery
percentage and remaining battery minutes, and receiver/transmitter warnings.
`?` means unavailable or stale, including when a transmitter does not provide battery information;
it is different from zero or an unmuted state. Warning text is reported by
the receiver. Battery runtime is available only when the transmitter reports
it. These controls are read-only and do not change receiver settings.

The documented SSCv1 and SSCv2 EW-DX interfaces expose a channel-level RF
strength and the selected antenna, but not separate per-antenna strength
values. The plugin therefore shows the selected antenna without inventing
individual antenna levels. Each meter has a numeric output pin and a
separate **Meter Valid** output pin. When a reading is unavailable or stale,
its text shows `?`, the bar clears to its minimum, and its validity pin is
false. The RF bar spans -107 to 0 dBm, audio spans -138.5 to 0 dBFS, and link
quality and battery span 0 to 100%. Check meter appearance and sizing on each
target UCI.

The online LED indicates a recent valid receiver response, not that every
field is available. Individual values expire after 40 seconds without an
update. The receiver is marked offline after 40 seconds without a response,
or immediately on SSCv2 authentication or transport failure. Other errors
are shown in **Last Error**, which retains the most recent error until the
configuration changes. SSCv2 422 for an unlinked transmitter is treated as
unavailable transmitter information, not an error.

SSCv1 sends read-only UDP requests to port 45 every two seconds. Each instance
asks the operating system for a local UDP port, avoiding a fixed-port bind
per instance. SSCv2 uses individual HTTPS GET requests, at most one
outstanding per instance and at most four requests per second. It polls
ten resources per channel in rotation, so a complete pass takes at least
five seconds for two channels or ten seconds for four, and longer when
requests are slow. This is not a real-time meter or SSE subscription. Polling
load and refresh timing depend on the target system and receiver.

Run `npm test` from the repository root for mocked protocol and layout tests.
They do not validate networking, HTTPS certificate behavior, actual Q-SYS
APIs, receiver firmware, or UCI rendering.

Protocol references: [SSCv1 EW-DX developer guide](https://docs.cloud.sennheiser.com/en-us/api-docs/resources/ew-dx-sound-control-protocol-3-0-x.pdf),
[EW-DX SSCv2 OpenAPI](https://docs.cloud.sennheiser.com/en-us/api-docs/open-api-ew-dx.html),
and [third-party access settings](https://docs.cloud.sennheiser.com/en-us/control-cockpit/ew-dx-access.html).
