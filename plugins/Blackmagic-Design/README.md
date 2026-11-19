# Blackmagic Design Videohub Plugin for the Q-SYS Platform

An early, open-source Q-SYS plugin for routing Blackmagic Videohub devices.
It provides a full crosspoint grid and an individually addressable control for
each input/output pair.

**Status: prototype.** The protocol and layout are covered by simulated tests,
but the plugin has not yet been validated in Q-SYS Designer, on a Core, in a
UCI, or against physical Videohub hardware. Do not rely on it for live use
until those checks are complete.

## Intended device profiles

Select the model in the plugin object's **Model** property before loading the
design. These are intended profiles, not a claim of hardware certification.

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
Constellation devices are not yet supported or tested. Compatible I/O counts
alone do not establish device or firmware compatibility. In particular, verify
the Mini's reported counts and front-input override behavior on hardware.

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
the label controls in a UCI where longer names are needed. The layout and
UCI control behavior need validation in the target Designer version.

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

The tests mock the Q-SYS socket, timer and controls APIs. They do not replace
Designer, UCI, network interoperability, or hardware tests. Before a release,
test each model and firmware, fragmented and asynchronous protocol updates,
disconnect/reconnect, output locks, IP changes, UCI linking, grid readability,
and Core/Designer performance with 400 crosspoints.

Protocol reference: [Blackmagic Videohub Ethernet Protocol](https://documents.blackmagicdesign.com/DeveloperManuals/VideohubEthernetProtocol.pdf).

## License

MIT; see [LICENSE](../../LICENSE).

Q-SYS is a trademark of QSC, LLC.
