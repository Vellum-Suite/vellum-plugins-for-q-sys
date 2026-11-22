# Sennheiser ew 300/500 Monitor for Q-SYS

Monitor multiple networked Sennheiser evolution wireless receivers from one
plugin instance. This implementation follows the documented ew G3/G4 media
control protocol.

**Status: tested.** The plugin has been tested in Q-SYS Designer and with
physical receiver hardware. Compatibility may vary by model and firmware.

The protocol documentation lists EM 300 G3, EM 500 G3 and EM 300-500 G4
receivers with firmware 1.7.0 or later. EM 100 G3/G4 receivers are not
supported by that protocol. This plugin assumes all configured receivers
use the same protocol; it does not detect or verify the model or firmware.
IEM transmitters and other Sennheiser product families are outside its scope.

## Installation and operation

1. Import [Sennheiser-ew-300-500.qplug](Sennheiser-ew-300-500.qplug) into
   Q-SYS Designer and add it to a design.
2. Set **Receiver Count** in the component properties (1–32). Changing the
   count changes the generated controls and may require UCI links to be checked.
3. Load or emulate the design. Enter a unique receiver IPv4 address for each
   row on **Configuration**. The design or emulating computer must be able to
   reach each receiver. Emulation uses real network devices; it does not
   simulate a receiver.
4. Use **Monitoring** to view receiver strips, with up to eight columns per
   row. Each strip includes the name, frequency, antenna, pilot, mute causes,
   warnings, and numeric readings alongside RF, audio, and battery meters.
   Existing text values and the online indicator remain available as output
   control pins; `?` means unavailable information.

When updating an existing design, load the newer plugin version in Designer
and check the generated controls and UCI links.

An online LED indicates a valid recent cyclic monitoring value, not a UDP
connection or confirmation that every field is available. If cyclic
telemetry stops for five seconds, the plugin marks the receiver offline and
clears its values. Individual cyclic fields also expire after five seconds;
name and frequency expire after 35 seconds without an update. Battery values
are the discrete percentages reported by the protocol (0, 30, 70, 100), or
`?` when unavailable. The RF 1 and RF 2 meters show each antenna's **maximum
since the last update**, not its current instantaneous level. Their minimum
and maximum values and "active since last update" flags are also exposed as
text output pins. The existing antenna field shows the current selection.
RF and audio values are protocol percentages and can exceed 100; the bars
are capped at 100 while the text readouts preserve the reported value. Audio
peak is the reported peak-hold value. Warning strings are shown as reported
by the receiver. Current mute causes come from the AF attribute, not the
historical States flags.

Each meter has a numeric output pin and a separate **Meter Valid** output pin.
An unavailable or stale reading clears the bar to zero and sets its validity
pin false; its text readout shows `?`, so it is distinguishable from a valid
zero. Check meter appearance and sizing on each target UCI.

The plugin binds local UDP port 53212 and sends to port 53212 on each
receiver. It renews a 30-second push subscription every 10 seconds, requests
cyclic updates every 500 ms, and queries name and frequency when subscribing.
Duplicate or invalid addresses are flagged. An empty address is left
unconfigured. When an address changes, the plugin requests that the previous
receiver stop sending updates.

Each instance has one socket for all its configured receivers. Use one
instance per Core for these receivers: another instance or script binding the
same local UDP port may prevent the socket from opening. Socket errors are
shown in **Last error** and opening is retried every 10 seconds. Isolate the
control network appropriately; the documented protocol does not specify
authentication.

## Development

Run `npm test` from the repository root. Tests mock Q-SYS sockets, timers and
controls; they cannot establish Designer compatibility or validate actual
receiver behavior, networking, firmware, or the UCI layout.

Protocol references: [ew G3 and 2000 series](https://www.manualshelf.com/manual/sennheiser/em-300-g3/media-control-protocol-for-ew-g3-and-2000-series-english.html)
and [ew G4 series](https://www.manualshelf.com/manual/sennheiser/em-300-500-g4-aw/media-control-protocol-for-ew-g4-series-english.html).

## License

MIT; see [LICENSE](../../LICENSE).

Q-SYS is a trademark of QSC, LLC. Sennheiser and evolution wireless are
trademarks of Sennheiser.
