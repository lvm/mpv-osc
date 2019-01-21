-- some of the code was salvaged from other projects.
-- such as:
--- decode_float:
---- lua-MessagePack  0.5.1
---- Copyright (c) 2012-2018 Francois Perrad"
---- licensed under the terms of the MIT/X11 license

require("mp.options")
require("mp.msg")
local socket = require("socket")
local floor = require'math'.floor
local huge = require'math'.huge
local ldexp = require'math'.ldexp or require'mathx'.ldexp

local options = {
  port = 5005,
}
read_options(options, "osc")

local decode_float = function (s)
   if #s < 4 then
      error "missing bytes"
   end
   local b1, b2, b3, b4 = s:sub(1, 4):byte(1, 4)
   local sign = b1 > 0x7F
   local expo = (b1 % 0x80) * 0x2 + floor(b2 / 0x80)
   local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4
   if sign then
      sign = -1
   else
      sign = 1
   end
   local n
   if mant == 0 and expo == 0 then
      n = sign * 0.0
   elseif expo == 0xFF then
      if mant == 0 then
         n = sign * huge
      else
         n = 0.0/0.0
      end
   else
      n = sign * ldexp(1.0 + mant / 0x800000, expo - 0x7F)
   end
   return n
end

local next_string = function(astring)
   local pos = 0
   local num_nzero = 0
   local num_zero = 0
   local result = ""
   if astring == nil then
      error("error: string is empty - probably malformated message")
   end
   for c in string.gmatch(astring, ".") do
      pos = pos + 1
      -- and then check if it is correctly padded with '\0's
      if c ~= '\0' and num_zero == 0 then
         num_nzero = (num_nzero + 1) % 4
         result = result .. c
      elseif num_zero > 0 and (num_zero + num_nzero) % 4 == 0 then
         return result, pos
      elseif c == '\0' then
         num_zero = num_zero + 1
         result = result .. c
      else
         return nil
      end
   end
   if num_zero > 0 and (num_zero + num_nzero) % 4 == 0 then
      return result, pos
   end
end

local collect_decoding_from_message = function(data, message)
   table.insert(message, decode_float(data))
   return string.sub(data, 5)
end

local get_addr_from_data = function(data)
   local addr_raw_string,last = next_string(data)
   local result = ""
   if addr_raw_string == nil then
      -- if we could not find an addr something went wrong
      error("error: could not extract address from OSC message")
   end
   -- delete possible trailing zeros
   for t in string.gmatch(addr_raw_string, "[^%z]") do
      result = result .. t
   end
   return result, string.sub(data, last)
end

local get_types_from_data = function(data)
   local typestring, last = next_string(data)
   local result = {}
   if typestring == nil then
      return {}
   end
   -- split typestring into an iterable table
   for t in string.gmatch(typestring, ",f") do
      table.insert(result, t)
   end
   return result, string.sub(data, last)
end

local decode_message = function(data, server)
   local message = {}
   local addr, tmp_data = get_addr_from_data(data)
   if not server:doesHandle(addr) then return end

   local types
   types, tmp_data = get_types_from_data(tmp_data)
   if addr == nil or types == nil then
      return nil
   end
   message.addr = addr
   for _,t in ipairs(types) do
      tmp_data = collect_decoding_from_message(tmp_data, message)
   end
   return server:handle(message)
end

local decoder = function (data, server)
   if #data == 0 then
      return nil
   end
   return decode_message(data, server)
end

local to_number = function(param)
   local num = tonumber(param)
   if not num then
      return 0.0
   else
      return num
   end
end

local set_position = function(t)
   return pcall(mp.command, "seek "..to_number(t).." absolute-percent")
end

local toggle = function()
   local curr = mp.get_property_bool("pause")
   return pcall(mp.set_property_bool, "pause", not curr)
end

local play = function()
   return pcall(mp.set_property_bool, "pause", false)
end

local pause = function()
   return pcall(mp.set_property_bool, "pause", false)
end

local osc = function(host, port)
   local this = {}
   this.udp = socket.udp()
   this.udp:settimeout(0)
   this.udp:setsockname(host, port)
   this.handlers = {}

   this.handle = function(self, decodedMessage)
      for k,v in pairs(self.handlers) do
         if string.match(decodedMessage.addr, '^'..k..'$') then
	    local status, err = pcall(v, decodedMessage.addr, unpack(decodedMessage))
	    if not status then
               print("Error in handler function: " .. err)
            end
         end
      end
   end

   this.doesHandle = function(self, addr)
      for pattern, _ in pairs(self.handlers) do
         if string.match(addr, '^'..pattern..'$') then return true end
      end
      return false
   end

   this.update = function (self)
      while true do
         local message = self.udp:receive(1024)
         if message == nil then break end
         local success, err = pcall(decoder, message, self)
         if not success then
            print("Error in decoding: \n" .. err)
         end
      end
   end

   return this
end

local server = osc("*", options.port)
server.handlers["/play"] = function(_address, action, ...) play() end
server.handlers["/pause"] = function(_address, action, ...) pause() end
server.handlers["/toggle"] = function(_address, action, ...) toggle() end
server.handlers["/position"] = function(_address, action, ...) set_position(action) end

mp.add_periodic_timer(0.2, function() server:update() end)
