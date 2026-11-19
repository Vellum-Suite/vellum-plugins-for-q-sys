# Blackmagic Design Videohub Plugin for the Q-SYS Platform

An open-source Q-SYS plugin for routing Blackmagic Videohub devices. It
provides a full crosspoint grid and an individually addressable control for
each input/output pair.

**Status: tested.** The plugin has been tested in Q-SYS Designer and with
physical Blackmagic Videohub hardware. The
profiles below describe the device configurations available in the plugin;
compatibility may vary by model and firmware.

## Device profiles

Select the model in the plugin object's **Model** property before loading the
design.

| Model | Inputs | Outputs | Crosspoints |
| --- | ---: | ---: | ---: |
| Videohub Mini 4x2 12G | 4 | 2 | 8 |
| Videohub 10x10 12G | 10 | 10 | 100 |
| Videohub 20x20 12G | 20 | 20 | 400 |
| Smart Videohub 12x12 | 12 | 12 | 144 |
| Smart Videohub 16x16 | 16 | 16 | 256 |
| Smart Videohub 20x20 | 20 | 20 | 400 |
| Smart Videohub CleanSwitch 12x12 | 12 | 12 | 144 |

Devices larger than 20x20 are not supported. Other Videohubs and ATEM
Constellation devices are not supported. Compatible I/O counts alone do not
establish device or firmware compatibility. In particular, verify the Mini's
reported counts and front-input override behavior on the target hardware.

## Installation and operation

1. Import [Blackmagic-Design-Videohub.qplug](Blackmagic-Design-Videohub.qplug)
   into Q-SYS Designer and add it to a design.
2. Select the matching **Model** property. Changing models changes the set of
   generated controls and may require UCI links to be checked.
3. Load or emulate the design. On the **Connection** page, enter the device's
   IPv4 address. The plugin connects to TCP port 9990.
4. On **Crosspoints**, outputs are rows and inputs are columns. A button
   requests a route immediately; its active state follows the routing reported
   by the device, including changes made by other clients.

On startup or reconnect the plugin waits for valid device I/O counts and a
route for every configured output. The **Ready** LED on the Connection page
lights only while the device is connected and routing is synchronized; it is
also available as an output control. A count mismatch blocks switching. The
reported model name is informational: profiles with equal I/O sizes cannot
be distinguished by count. On disconnect, route indicators are cleared, not
retained as if they were current. Commands are not queued or replayed.
If the initial status is incomplete after 15 seconds, the plugin reports a
synchronization error and continues waiting for valid routing feedback.

Every grid button has a stable name, `Crosspoint OO II`, using one-based
output and input numbers (for example `Crosspoint 03 12`). Its displayed
pretty name groups it by output and input. Labels and lock status are separate
output controls; renaming device ports does not change crosspoint identities.
Lock states are `U` (unlocked), `O` (owned by this client), `L` (locked by
another client), and `?` (unknown). The plugin does not change locks and
rejects a route locally when the last reported state is `L`. A device can
still reject a request; check **Last error**. `ACK` is not treated as route
confirmation.

The full 20x20 grid is wide. Names may be truncated in the plugin view; use
the label controls in a UCI where longer names are needed.

The Videohub protocol has no authentication; place devices and the Core on a
trusted, appropriately isolated control network. CleanSwitch's clean
transitions depend on compatible video formats and synchronization; a routing
request alone does not ensure a clean switch.

## Development

The plugin is the single `.qplug` source file; no build step is required.
Tests use Node.js and the Fengari Lua runtime. Run these commands from the
repository root:

```powershell
npm install
npm test
```

The automated tests mock the Q-SYS socket, timer and controls APIs. They
complement, but do not replace, validation with the target device model and
firmware, network setup, and UCI layout.

Protocol reference: [Blackmagic Videohub Ethernet Protocol](https://documents.blackmagicdesign.com/DeveloperManuals/VideohubEthernetProtocol.pdf).

## License

MIT; see [LICENSE](../../LICENSE).

Q-SYS is a trademark of QSC, LLC.
