# SyncBrightness

Change your Mac's built-in display brightness with F1 and F2 keys. Builds upon [ddcctl](https://github.com/kfix/ddcctl) by providing a daemon which responds to the function keys and maintains a brightness state.

## Building

Build with Xcode.

## Usage

SyncBrightness takes no arguments, and stays alive, controlling the brightness with the function keys, until terminated by the user. It is recommended to create a launch agent to keep the daemon alive.

An optional `.SyncBrightness.conf` can be added to your home folder, which SyncBrightness reads to perform monitor-specific adjustments of the brightness. Each line should consist of a monitor's serial number, a relative min brightness and a max brightness separated by spaces. Different monitors can have different brightness ranges, with the master range being the total overlapping range. Values outside a monitor's range are clamped.

### Example Configuration

```
ABC123456789  0.0 1.0
DEF987654321 -0.5 1.0
```

| Master | ABC | DEF |
| ------ | --- | --- |
| 0.0    | 0.0 | 0.0 |
| 0.2    | 0.0 | 0.2 |
| 0.4    | 0.1 | 0.4 |
| 0.6    | 0.4 | 0.6 |
| 0.8    | 0.7 | 0.8 |
| 1.0    | 1.0 | 1.0 |
