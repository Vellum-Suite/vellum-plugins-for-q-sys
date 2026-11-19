# Vellum Plugins for the Q-SYS™ Platform

Open-source integrations for third-party AV devices, developed by Vellum.

## Find a plugin

Installable `.qplug` files are in the `plugins` folder, grouped by device
manufacturer. Each manufacturer folder also contains its plugin's setup and
compatibility information.

| Manufacturer | Plugin | Status |
| --- | --- | --- |
| Blackmagic Design | [Videohub plugin](plugins/Blackmagic-Design/Blackmagic-Design-Videohub.qplug) · [Instructions](plugins/Blackmagic-Design/README.md) | Tested in Q-SYS Designer and with physical Videohub hardware |

Download the `.qplug` file, then install it in Q-SYS Designer. See the
individual plugin instructions for device support, installation and caveats.

## Development

Tests live separately under `tests`, grouped by manufacturer, and are not
required to install a plugin. To run the current test suite from the
repository root, install Node.js and run:

```powershell
npm install
npm test
```

Add new plugins under `plugins/<manufacturer>/`, with their instructions
alongside them; place their tests under `tests/<manufacturer>/` and include
them in the root test command.

## License and trademarks

The code is available under the [MIT license](LICENSE).

Q-SYS is a trademark of QSC, LLC. Blackmagic Design and Videohub are
trademarks of Blackmagic Design.
