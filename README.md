# FreeDial

A small macOS app that puts a saved-address picker in front of [FreeRDP](https://www.freerdp.com)'s
SDL client (`sdl-freerdp`). Pick a machine and address from a drop-down, or type a new one, and
FreeDial connects with the password from your Keychain. It's meant for reaching the same
machines from different places, for example a `.local` name at home and a Tailscale address away.

FreeDial is not affiliated with the FreeRDP project.

## Install

Requirements: macOS 12 or later, the Xcode command line tools (`xcode-select --install`), and FreeRDP
(`brew install freerdp`; the installer offers to do this).

```sh
./install.sh                 # builds and installs ~/Applications/FreeDial.app
./install.sh --dest /Applications
```

Remove it with `./uninstall.sh`. Add `--purge` to also delete saved addresses, the log, and the
Keychain passwords.

## Use

Open FreeDial. It shows two editable drop-downs:

- **Machine**: a name for the computer. The password is saved per machine.
- **Address**: where to reach it (host name or IP, optionally `:port`; the default port is 3389).
  Each machine can have several addresses, and picking a machine lists its addresses.

Connect saves the pair and moves it to the top of the list. The first time you use a machine it asks for
the RDP password and stores it in your Keychain; after that there's no prompt. If the connection fails
within about six seconds you get an error dialog. Closing the RDP window afterwards is silent.

## Files

| Path | What |
|---|---|
| `~/.config/freedial/hosts.tsv` | Saved entries, one `machine<TAB>address` per line, most recent first |
| `~/.config/freedial/config` | Optional. `user=name` sets the RDP username (default: your macOS login name) |
| `~/Library/Logs/freedial.log` | Output of the last connection |
| Keychain item `rdp-<machine>` | The password, with your RDP username as the account |

## Notes

- Passwords are saved by the app through the Keychain API and passed to FreeRDP on stdin, so they never
  appear in a process's arguments. macOS may ask once to let `security` read an item the app created.
- FreeDial trusts a server's certificate the first time you connect to an address (`/cert:tofu`).
- IPv6 literals need an explicit port, for example `[fd00::1]:3389`.
- This uses FreeRDP's SDL client because it opens a native window without XQuartz.

## License

Apache License 2.0, the same as FreeRDP. See [LICENSE](LICENSE).
