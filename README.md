# SyncBrightness

Automatically synchronises your Mac's built-in display brightness with all attached monitors using [DDC](https://en.wikipedia.org/wiki/Display_Data_Channel). Builds upon [ddcctl](kfix/ddcctl) by periodically reading the built-in display brightness and copying it to the external monitors.

## Building

Build with Xcode.

## Usage

SyncBrightness takes no arguments, and stays alive, syncing the brightness, until terminated by the user. It is recommended to create a launch agent to keep the daemon alive.

An optional `.SyncBrightness.conf` can be added to your home folder, which SyncBrightness reads to perform monitor-specific adjustments of the brightness. Each line should consist of a monitor's serial number, the min brightness and the max brightness separated by spaces. The brightness is a number between 0 and 1, and corresponds to the desired brightness levels of the external monitor on the extremes of the built-in display, which is then normalised.

### Example Configuration

```
ABC123456789 -0.5 1.0
```

|----------|------------|
| Built-in | External   |
|----------|------------|
| 0.0      | -0.5 → 0.0 |
| 0.2      | -0.2 → 0.0 |
| 0.4      | 0.1        |
| 0.6      | 0.4        |
| 0.8      | 0.7        |
| 1.0      | 1.0        |
|----------|------------|