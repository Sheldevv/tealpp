## Recovering from a botched "hide system lua" test

If you moved your system `lua` to `/tmp/lua.bak` and the restore failed
(e.g. read-only `/usr` on Fedora Atomic / Bazzite / Silverblue / SteamOS):

```sh
sudo mv /tmp/lua.bak /usr/local/bin/lua
sudo chmod +x /usr/local/bin/lua
lua -v
```

Safer alternative for testing AppImage self-containment without touching
system files:

```sh
env PATH=/usr/bin:/bin ./tealpp-1.0-x86_64.AppImage --help
```

This hides anything in /usr/local/bin, ~/.local/bin, ~/.cargo/bin, etc.,
without moving files. Fully reversible — just drop the `env` prefix.
