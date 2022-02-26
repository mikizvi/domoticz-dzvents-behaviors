# Prebuilt/precooked behavior idioms for Domoticz dzVents
Michael Hirsch  
February 2022

In the [Domoticz](https://www.domoticz.com/) home automation system, event behaviors can be defined in Lua using a subsystem called [dzVents](https://www.domoticz.com/wiki/DzVents:_next_generation_Lua_scripting).  The functions in the `behaviors.lua` file provide idioms for behavior combinations that were found to be useful.

For example, several single-pole mechanical switches in my house were replaced by multi-pole [Sonoff](https://sonoff.tech/product/smart-wall-swtich/tx-series/) switches with [Tasmota](https://tasmota.github.io/docs/) firmware.  The behaviors here tie these spare switches to other lights logically or make them into "main" switches.  In my case, we now have light switches for the important lights at all doors.

Note that there is no attempt to detect or handle interactions.  Declaring multiple devices as "same" and "exclusive" devices will cause infinite loops.

I'm sure that there are ways to achieve the same results with existing Domoticz facilities like "Scenes" or "Groups".  This approach, though, puts all the behaviors in the Events dzVents, which makes it easy to find and trace.

## Example

Example contents of a dzVents device event:
```
behaviors = require('behaviors')
return behaviors.define_same_devices(domoticz, 'example set', {'switch-1', 'switch-2'})
```
This would define switch-1 and switch-2 as synonyms.  The name "example set" is used as a tag in the logs.  This assists in tracing why things happened.  If there is a some kind of main switch, its name is used as the log tag.

## How it works

The functions in the "behaviors" module encode the desired functionality.  They use the parameters (generally device names or tables of device names) to build the dzVent table with the necessary custom `on` and precooked `execute` keys.  This saves a lot of copy-paste and potential errors as a result.

## Deployment

Place the `behaviors.lua` file in the `scripts/dzVents/modules` directory of your Domoticz installation.  You may need to create this directory.  After upgrades, check that this file survived the upgrade.

Inside Domoticz, events are here: `Setup->More Options->Events`.  Create a new event with `+->dzVents->Device`.  A meaningful name will help you find it later.  As a suggestion, use the same name as the set name (log tag) parameter.  Replace the contents of the editor window with the examples below, changing the device names.

All the behaviors here need device (switch) names.  Needless to say, you need unique (meaningful?) device names.  Copy/paste is recommended, especially to avoid errors in upper/lower case or "-"/"_".  If you get a name wrong, the behavior won't work as expected.  All name errors are supposed show up in the log.  You can find the log in `Setup->Log`.  If you want to search it as file, look in `/tmp/domoticz.log` or `/opt/domoticz/userdata/domoticz.log` inside the Domoticz container.  It is strongly recommended that you check the log after every event edit.

## define_same_devices: Multiple switches for the same device

Use this when you have one light that can be switched on and off from multiple places.
```
behaviors = require('behaviors')
return behaviors.define_same_devices(domoticz, 'example set', {'switch-1', 'switch-2', 'switch-3'})
```
This would define switch-1, switch-2, and switch-3 as synonyms.  The table of synonym switches can contain 2 or more switches.

## exclusive_devices: At most one device can be on at a time

Multiple devices that must never be on at the same time.  Possibly 2 heaters on the same circuit: switching one on will switch the other off, preventing overloads.

```
behaviors = require('behaviors')
return behaviors.exclusive_devices(domoticz, 'excl-123', {'exclusive-1', 'exclusive-2', 'exclusive-3'})
```

This defines exclusive-1, exclusive-2, and exclusive-3 as mutually exclusive.  Turning any one on will ensure that the rest of the devices in the list are turned off.

## main_switches_all: One device switches on and/or off a list of devices

One switch that switches multiple devices on or off at the same time.

```
behaviors = require('behaviors')
return behaviors.main_switches_all(domoticz, 'main-switch', 'Any', {'sub-1', 'sub-2', 'sub-3'}})
```

Switching the `main-switch` on will switch on any of the sub switches that aren't on, and switching it off will switch off any that aren't off.  If you only want the _on_ part, replace 'Any' with 'On'.  Similarly for _off_, replace 'Any' with 'Off'.

## timed_devices: Switch off after a timeout

Lights that people forget to switch off?  Heaters/boilers/pumps that must not stay on too long?  Use this behavior to trigger switching them off automatically.

```
local these_devices = {
	['timed-3-min'] = 3,
	['timed-10-min'] = 10,
	['timed-15-sec'] = {timeout = 15, unit = 'second'},
};

behaviors = require('behaviors')
return behaviors.timed_devices(domoticz, 'timed_devices', these_devices)
```

In this example, the `timed-<time>` devices will be switched off after their respective timeouts.  The `unit` field can be 'second', 'minute', or 'hour'.

dzVents provides primitives for changing the state of a device after timeouts.  This behavior uses them, but provides simpler syntactic sugar for the common case, without needing to set up multiple separate events.

## cascade: a device is switched on if any trigger device goes on

Any one of a number of lower level devices causes a higher level device to be switched on.  These could be to trigger a common light to go on when the light at any door is switched on.  Another use is to trigger a main alarm when any sub alarm triggers.

```
behaviors = require('behaviors')
return behaviors.cascade(domoticz, 'cascade-main', {'sub-1', 'sub-2'})
```

This will trigger switching `cascade-main` on if either of `sub-1` or `sub-2` is switched on.

## Format hint

Whenever a list of devices is needed, these can be defined as a local table before the rest of the code.

```
local these_devices = {
	'all-on-off-sub-1',
	'all-on-off-sub-2',
	'all-on-off-sub-3',
};

behaviors = require('behaviors')
return behaviors.main_switches_all(domoticz, 'main-switch', 'Any', these_devices)
```

## Log hint

If strange things start happening, take a look at the log.  Search for the names of the relevant devices.  Look for messages like this: `exclusive(excl-1-2): Switching off exclusive-2 because exclusive-1 was switched on`.   You can find the log in `Setup->Log`.  If you want to search it as file, look in `/tmp/domoticz.log` or `/opt/domoticz/userdata/domoticz.log` inside the Domoticz container.

## References

[Domoticz](https://www.domoticz.com/)  
[dzVents](https://www.domoticz.com/wiki/DzVents:_next_generation_Lua_scripting)  
[Sonoff TX switches](https://sonoff.tech/product/smart-wall-swtich/tx-series/)  
[Tasmota](https://tasmota.github.io/docs/)

## Keywords

Domoticz, dzVents, home automation, smart home, behavior idioms

## License

   Created on: 2022-02-26

   Copyright (c) 2022 Michael Hirsch. All rights reserved.

   This project is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3.0 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
