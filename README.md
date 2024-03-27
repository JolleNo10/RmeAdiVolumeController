# RmeAdiVolumeController

Scripts for interacting with the ADI-2 DAC / ADI-2 Pro / ADI-2/4 Pro SE through the Midi interface.

Currently supports volume up, down and mute as this is all I needed when I wrote the script, but can easily be extended.
Volume up and down was written to support a volume wheel controller.

Midi commands are based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip

The byte conversion is based on a script provided by user danadam at https://www.audiosciencereview.com/forum/index.php?threads/rme-adi-2-remote-app-race-for-the-best-alternative-software-was-started-today.48352/#post-1733256 so all credit to him for the conversion code.

These scripts were originally tailored to meet my requirements for my personal setup. 
As a result, the code quality may reflect this this!

## Table of Contents

1. [Introduction](#Features)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Contributing](#contributing)
5. [License](#license)

## Features and usage
*Usage*
volcontrol.sh mute - Mutes the RME ADI unit, multiple calls will toggle mute on and off
volcontrol.sh down - Increases volume by a configurable value (default 0.5db)
volcontrol.sh up - Decreases volume by a configurable value (default 0.5db)

Volume up and down supports a scroll wheel. Fast turning/triggering, will increase/decrease the volume in larger steps. 
Configurable with "volumeTickMultiplierTimeThreshold" (threshold time between changes) and "volumeTickMultiplier" (multiplies the normal volume change by x)

Script does not currently support reading state from the RME ADI unit. 
The script will set a default value and send it to the RME ADI unit as a startingpoint defaultVolume (default -35db) and defaultMute (default off) and track any change relative to this.

Because I was afraid of blowing up my headphones during scripting, a max and min value is set on the volume (highVolume, lowVolume). If the volume is set outside of the boundry, it will cycle back to defaultVolume.
Can be configured to match the The RME ADI max and min values: min: 1140 (-114db) and max: 60 (6db). Change at your own risk. 

Usage:
volcontrol.sh up <command>
- volcontrol.sh mute : Mutes the RME ADI unit. Concurrent triggers will toggle mute on and off.
- volcontrol.sh down : Decreases volume by 0.2dB (configurable value).
- volcontrol.sh up : Increases volume by 0.2dB (configurable value).

The volume up and down commands support a scroll wheel. Rapid turning or triggering will adjust the volume in larger steps than the default value. 
This behavior is configurable with parameters `volumeTickMultiplierTimeThreshold` (threshold time between changes) and `volumeTickMultiplier` (multiplier for the normal volume change).

Currently, the script does not support reading state from the RME ADI unit. Instead, it sets a default value and sends it to the RME ADI unit as a starting point. 
The default volume is set to `defaultVolume` (default: -35dB) and the default mute state is `defaultMute` (default: off). 
The script then tracks any changes relative to these defaults. 

Because I was afraid of blowing up my headphones during scripting, the script enforces maximum and minimum volume limits (`highVolume` and `lowVolume`). 
If the volume is set outside these boundaries, it will cycle back to `defaultVolume`. 
You can configure these limits to match the RME ADI's maximum and minimum values: min: 1140 (-114dB) and max: 60 (6dB). If you have high impedance Headphones, you might want to change the highVolume boundry.
However, make changes to this at your own risk.

### Debugging and logging
You can debug the execution by adding LogLevel and logoverride as parameters:

volcontrol.sh up <loglevel> <logoverride>

For example: 
volcontrol.sh up DEBUG 1

There are three log levels: DEBUG, INFO, and ERROR. 
"logoverride" overrides the enableLogging configuration.

I suggest using logging only for debugging purposes. 
There are no log rotation implemented, and it may slow down execution.

## Installation
Copy both scripts to your prefered script folder, make executable for your user.

## Configuration
1. Change rmeAdiMidiControlScript location to match your script folder.
2. Set rmeCurrentVolumeFile and logfile to whatever you want.
3. Maybe check permissions of the files, haven't verified it.

## Contributing
I welcome contributions from the community to improve this project! If you'd like to contribute, let me know!

### Making Changes
If you'd like to contribute code changes, enhancements, or new features, feel free to make a fork

## License
This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License. 
To view a copy of this license, visit [here](https://creativecommons.org/licenses/by-nc/4.0/) or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.

You are free to:
- Share — copy and redistribute the material in any medium or format
- Adapt — remix, transform, and build upon the material

Under the following terms:
- Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
- NonCommercial — You may not use the material for commercial purposes.

- ## Disclaimer

**Use at Your Own Risk:**

The scripts is provided as-is, without any warranty or guarantee of any kind. 
The author assumes no responsibility or liability for the accuracy, reliability, completeness, or usefulness of the information provided by the script. 
The user of this script assumes all risks associated with its use. The author shall not be held responsible for any damages or losses that result from the use of this script. 

**Please use it responsibly and at your own risk.**