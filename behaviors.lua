--[[
   behaviors.lua
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

---

   In the Domoticz home automation system, event behaviors can be defined in Lua
   using a subsystem called dzVents.  The functions in this file provide idioms
   for behavior combinations that I found useful.

   Place this file in the scripts/dzVents/modules directory of your Domoticz installation.
   If you upgrade Domoticz, check that this file survived the upgrade.

   Example contents of a dzVents device event:
      behaviors = require("behaviors") -- this file
      return behaviors.define_same_devices(domoticz, "example set", {"switch_1", "switch_2"})

   This would define switch_1 and switch_2 as synonyms.

   Read about dzVents here: https://www.domoticz.com/wiki/DzVents:_next_generation_Lua_scripting
   Please see the accompanying README.md file for more details.
]]

--- Defines behaviours for devices and for sets of devices.
local behaviors = {}

local function get_peer(domoticz, peer_name, name)
   local peer
   local status
   if (peer_name == name) then
      return nil, nil
   end
   status, peer = pcall(domoticz.devices, peer_name)
   if (not status or not peer) then
      status, peer = pcall(domoticz.groups, peer_name)
   end
   if (not status or not peer) then
      domoticz.log("Peer "..peer_name.." of device "..name.." does not exist",
               domoticz.LOG_ERROR)
   end
   return status, peer
end

local function set_devices_to_state(domoticz, name, state, these_devices)
   for _, peer_name in pairs(these_devices) do
      local status, peer = get_peer(domoticz, peer_name, name)
      if (not status or not peer) then
         goto continue
      end
      if (peer.state ~= state) then
         peer.setState(state)
         domoticz.log(state.." for "..peer_name.." because "..name.." was changed",
            domoticz.LOG_INFO)
      end
      ::continue::
   end
end

local function do_all_devices_have_state(domoticz, name, state, these_devices)
   for _, peer_name in pairs(these_devices) do
      local status, peer = get_peer(domoticz, peer_name, name)
      if (not status or not peer) then
         goto continue
      end
      if (peer.state ~= state) then
	     return false
      end
      ::continue::
   end
   return true
end

--- Multiple devices that need to be switched on and off together
-- Use this functionality when you have multiple switches for the same device.
-- Creator function for a Domoticz dzVent event
-- @param domoticz table: the Domoticz dzVents Lua control structure
-- @param set_name string: the name of the this set of devices
-- @param these_devices list of string: list of names of devices that belong to this set
-- @return table that defines the dzVents behavior
function behaviors.same_devices(domoticz, set_name, these_devices)
   return {
      on = {
         devices = these_devices
      },
      logging = {
         level = domoticz.LOG_INFO,
         marker = "same("..set_name..")"
      },
      execute = function(domoticz, device)
         local state = device.state
         local name = device.name
		 set_devices_to_state(domoticz, name, state, these_devices)
      end
   }
end

function behaviors.same_devices_groups(domoticz, set_name, these_devices, these_groups)
   all_devices = {}
   table.move(these_devices, 1, #these_devices, 1, all_devices)
   table.move(these_groups, 1, #these_groups, #all_devices + 1, all_devices)
   return {
      on = {
         devices = these_devices,
         groups = these_groups
      },
      logging = {
         level = domoticz.LOG_INFO,
         marker = "same_dev_gr("..set_name..")"
      },
      execute = function(domoticz, device)
         local state = device.state
         local name = device.name
		 set_devices_to_state(domoticz, name, state, all_devices)
      end
   }
end

--- Multiple devices that must never be on at the same time
-- Use this functionality to switch off alternate heavy current devices on the same
-- circuit to prevent overload.
-- Creator function for a Domoticz dzVent event
-- @param domoticz table: the Domoticz dzVents Lua control structure
-- @param set_name string: the name of the this set of devices
-- @param these_devices list of string: list of names of devices that belong to this set
-- @return table that defines the dzVents behavior
function behaviors.exclusive_devices(domoticz, set_name, these_devices)
   return {
      on = {
         devices = these_devices
      },
      logging = {
         level = domoticz.LOG_INFO,
         marker = "exclusive("..set_name..")"
      },
      execute = function(domoticz, device)
         local state = device.state
         if (state == "Off") then
            return
         end
         local name = device.name
		 set_devices_to_state(domoticz, name, "Off", these_devices)
      end
   }
end

--- Multiple devices are switched on or off according to a main switch
-- Use this functionality when a main switch needs to turn multiple devices on or off.
-- If you need a main switch to turn multiple devices on and off, use "any" for transition_to
-- Creator function for a Domoticz dzVent event
-- @param domoticz table: the Domoticz dzVents Lua control structure
-- @param main string: the main switch to track
-- @param transition_to string: triggers when the main switch transitions to this state
-- @param these_devices list of string: list of names of devices that must be transitioned to the same state
-- @return table that defines the dzVents behavior
function behaviors.main_switches_all(domoticz, main, transition_to, these_devices)
   if (transition_to == 'on') then
      transition_to = 'On'
   elseif (transition_to == 'off') then
      transition_to = 'Off'
   elseif (transition_to == 'any') then
      transition_to = 'Any'
   end
   return {
      on = {
         devices = { main }
      },
      logging = {
         level = domoticz.LOG_INFO,
         marker = "main_switches_all("..main..", "..transition_to..")"
      },
      execute = function(domoticz, device)
         local state = device.state
         if (transition_to ~= "Any") then
            if (state ~= transition_to) then
               return
            end
         end
         local name = device.name
		 set_devices_to_state(domoticz, name, state, these_devices)
      end
   }
end

--- Devices are switched off after a timeout.  Each device has its own timeout
-- Use this functionality to switch off devices automatically.  Could be devices that
-- are often forgotten or devices that should go off after a max time anyway to prevent overload.
-- Creator function for a Domoticz dzVent event
-- @param domoticz table: the Domoticz dzVents Lua control structure
-- @param set_name: the name of this rule
-- @param devices table: the key is the device name and the value is either:
--   a number of minutes (possibly a float) till the device should be switched off
-- or
--   a table with keys "timeout" and "unit",
--     where
--       timeout is the number of units till the device should be switched off (possible a float)
--       unit is "hour", "minute" or "second", default minute if missing
-- @return table that defines the dzVents behavior
--[[
local example_timed_devices =
{
   ['dev-1'] = {
      timeout = 5,
      unit = 'second'
   },
   ['dev-2'] = { -- 630 seconds
      timeout = 10.5,
      unit = 'minute'
   },
   ['dev-3'] = 5, -- 5 minutes
   ['dev-4'] = 0.5, -- 30 seconds
   good_name = 15, -- brackets and quote not needed
}
]]
function behaviors.timed_devices(domoticz, set_name, timed_devices)
   local function get_keys(list)
      local keys = {}
      for k,_ in pairs(list) do
         table.insert(keys, k)
      end
      return keys
   end

   local device_list = get_keys(timed_devices)

   return {
      on = {
         devices = device_list
      },
      logging = {
         level = domoticz.LOG_INFO,
         marker = "timed_devices("..set_name..")"
      },
      execute = function(domoticz, device)
         local state = device.state
         if (state ~= "On") then
            return
         end
         local name = device.name
         local params = timed_devices[name]
         local seconds
         if (tonumber(params) ~= nil) then
            seconds = tonumber(params) * 60
         elseif (params.unit == 'second') then
            seconds = params.timeout
         elseif (params.unit == 'minute' or params.unit == nil) then
            seconds = params.timeout * 60
         elseif (params.unit == 'hour') then
            seconds = params.timeout * 3600
         else
            domoticz.log("Processing "..name..": unit = "..params.unit.." not recognized", domoticz.LOG_INFO)
            return
         end

         device.cancelQueuedCommands()
         if (seconds > 0) then
            device.switchOff().afterSec(seconds)
            domoticz.log("Scheduled Off for "..name.." in "..seconds.." seconds", domoticz.LOG_INFO)
         end
      end
   }
end

--- Multiple devices trigger a main
-- Use this functionality when any of a number of devices causes a main switch to turn on
-- For example: sub-alarms triggering a main alarm
-- Creator function for a Domoticz dzVent event
-- @param domoticz table: the Domoticz dzVents Lua control structure
-- @param main string: the main switch to trigger
-- @param these_devices list of string: any of these devices will trigger the main device
-- @return table that defines the dzVents behavior
function behaviors.cascade(domoticz, main_name, these_devices)
   return {
      on = {
         devices = these_devices
      },
      logging = {
         level = domoticz.LOG_INFO,
         marker = "cascade("..main_name..")"
      },
      execute = function(domoticz, device)
         local state = device.state
         local name = device.name
         if ((state ~= 'On') and (state ~= 'Group On')) then
            return
         end
         local main = domoticz.devices(main_name)
         if (main == nil) then
            domoticz.log("Main "..main_name.." of device "..name.." does not exist",
               domoticz.LOG_ERROR)
            return
         end
         if (main.state ~= 'On') then
            main.setState('On')
            domoticz.log(state.." for "..main_name.." because "..name.." was changed",
               domoticz.LOG_INFO)
         end
      end
   }
end

--- A main device controls a group of switches
-- Use this functionality when the main switches all on or off, and all on or off cause the main to follow
-- This is the equivalent of a Domoticz group with an assigned main switch
-- Creator function for a Domoticz dzVent event
-- @param domoticz table: the Domoticz dzVents Lua control structure
-- @param main string: the main switch to trigger
-- @param these_devices list of string: any of these devices will trigger the main device
-- @return table that defines the dzVents behavior
function behaviors.dzv_group(domoticz, main_name, these_devices)
   all_devices = {}
   main_devices = { main_name }
   table.move(these_devices, 1, #these_devices, 1, all_devices)
   table.move(main_devices, 1, #main_devices, #all_devices + 1, all_devices)
   return {
      on = {
         devices = all_devices
      },
      logging = {
         level = domoticz.LOG_INFO,
         marker = "dzv_group("..main_name..")"
      },
      execute = function(domoticz, device)
         local state = device.state
         local name = device.name
		 if (name == main_name) then
		    set_devices_to_state(domoticz, name, state, these_devices)
			return
		 end
         if (not do_all_devices_have_state(domoticz, name, state, these_devices)) then
            return
         end
         local main = domoticz.devices(main_name)
         if (main == nil) then
            domoticz.log("Main "..main_name.." of device "..name.." does not exist",
               domoticz.LOG_ERROR)
            return
         end
         if (main.state ~= state) then
            main.setState(state)
            domoticz.log(state.." for "..main_name.." because "..name.." was changed",
               domoticz.LOG_INFO)
         end
      end
   }
end

return behaviors

