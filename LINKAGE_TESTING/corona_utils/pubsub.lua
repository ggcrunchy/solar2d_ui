--- A list that follows the pub-sub pattern. 

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local find = string.find
local format = string.format
local pairs = pairs
local setmetatable = setmetatable
local sub = string.sub
local tonumber = tonumber
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")

-- Cached module references --
local _MakeEndpoint_

-- Exports --
local M = {}

--
--
--

-- Check whether a candidate resembles a result of @{MakeEndpoint}.
--
-- **N.B.** Currently this only checks for strings containing a known separator, rather than
-- rigorously validating the ID and name as well. This suffices to ignore common inputs like
-- **nil** and non-strings, but is vulnerable to hand-crafted not-quite-endpoints.
-- @param candidate
-- @string[opt] how If this is **"split"** and _candidate_ is valid, return ID and name.
-- @treturn[1] uint The ID preceding the separator...
-- @treturn[1] string ...and the name following it.
-- @treturn[2] boolean Was _endpoint_ valid?
function M.IsEndpoint (candidate, how)
	if type(candidate) == "string" then
		local pos = find(candidate, ":")

		if pos ~= nil then
			if how == "split" then
				return tonumber(sub(candidate, 1, pos - 1)), sub(candidate, pos + 1)
			else
				return true
			end
		end
	end

	return false
end

--- Builds an endpoint from an ID and name.
-- @uint id Identifier for a particular "object". This must be unique within the context of a group
-- of related @{PubSubList:Publish} and @{PubSubList:Subscribe} calls.
-- @string name Named feature to request from the "object" through this endpoint.
-- @treturn string Endpoint.
function M.MakeEndpoint (id, name)
	return format("%i:%s", id, name)
end

local PubSubList = {}

PubSubList.__index = PubSubList

--- Delivers published payloads to any subscribers waiting for them.
-- @see PubSubList:Publish, PubSubList:Subscribe, PubSubList:Wipe
function PubSubList:Dispatch ()
	for i = 1, #self, 3 do
		local endpoint, func, arg = self[i], self[i + 1], self[i + 2]

		func(self[endpoint], arg)
	end
end

--- Make a feature available on the endpoint described by _id_ and _name_, cf.
-- @{PubSubList:MakeEndpoint}. The payload will be delivered to any subscribers during a
-- call to @{PubSubList:Dispatch}, cf. @{PubSubList:Subscribe}.
--
-- This will overwrite (or remove, given a **nil** _payload_) any payload already published
-- on the same endpoint.
-- @param payload Named feature data provided by the "object".
-- @tparam ?|uint|nil id Identifier for the "object" publishing this feature. This might be
-- **nil**, in which case publishing is a no-op. (This is intended as a convenience to
-- streamline certain publishing patterns.)
-- @tparam ?|string|nil name Feature being published. Again, this might be **nil** and
-- thus produce a no-op.
-- @see PubSubList:Wipe
function PubSubList:Publish (payload, id, name)
	if id and name then
		self[_MakeEndpoint_(id, name)] = payload
	end
end

--- Listen for any payloads published on _endpoints_, cf. @{PubSubList:Publish}.
-- @tparam ?|string|{string,...}|nil endpoints 0, 1, or multiple publisher endpoints.
-- @callable func When @{PubSubList:Dispatch} is fired, `func(payload, arg)` will be called
-- for each requested endpoint with a published payload.
-- @param[opt=false] arg
-- @see PubSubList:Wipe
function PubSubList:Subscribe (endpoints, func, arg)
	arg = arg or false

	for _, v in adaptive.IterArray(endpoints) do
		self[#self + 1] = v
		self[#self + 1] = func
		self[#self + 1] = arg
	end
end

--- Wipe all payloads and subscribers from the list.
-- @see PubSubList:Publish, PubSubList:Subscribe
function PubSubList:Wipe ()
    for k in pairs(self) do
        self[k] = nil
    end
end

---
-- @treturn PubSubList Pub-sub list.
function M.New ()
	return setmetatable({}, PubSubList)
end

_MakeEndpoint_ = M.MakeEndpoint

return M