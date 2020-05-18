--- Various call-related building blocks, in particular for objects typically built up from data. 

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
local assert = assert
local rawequal = rawequal
local remove = table.remove
local setmetatable = setmetatable
local type = type

-- Modules --
local frames = require("solar2d_utils.frames")
local meta = require("tektite_core.table.meta")

-- Corona globals --
local Runtime = Runtime
local system = system

-- Cached module references --
local _IterateCallList_
local _MakePerObjectCallList_

-- Exports --
local M = {}

--
--
--

local Count, Limit = 0

local TryToResetCount = frames.OnFirstCallInFrame(function()
	Count = 0
end)

--- DOCME
-- @uint n
function M.AddCalls (n)
	TryToResetCount()

	local count = Count + n

	assert(Limit, "Calls require a limit")
	assert(count <= Limit, "Too many calls")

	Count = count
end

--- DOCME
-- @treturn boolean B
function M.AtLimit ()
	return Count == Limit
end

local Tally, LastReported, OnTooManyEvent = 0, 0

local function TryToReport ()
	local now = system.getTimer()

	Tally = Tally + 1

	if now - LastReported >= 3000 then -- throttle the reports
		OnTooManyEvent = OnTooManyEvent or {}
		OnTooManyEvent.name, OnTooManyEvent.tally = "too_many_actions", Tally

		Runtime:dispatchEvent(OnTooManyEvent)

		LastReported, Tally = now, 0
	end	
end

local function AdjustN (n)
	if Limit and Count + n > Limit then
		return Limit - Count
	else
		return n
	end
end

local BoxesStash = {}

local BoxNonce = BoxesStash -- arbitrary internal object

local function Box (func)
	local box = remove(BoxesStash)

	if box then
		box(BoxNonce, func)
	else
		function box (arg1, arg2)
			if rawequal(arg1, BoxNonce) then
				if arg2 == "get" then
					return func
				elseif arg2 == "extract" then
					arg2, func = func

					return arg2
				else
					func = arg2 -- N.B. captured at first, thus only need this on reuse
				end
			elseif arg1 ~= "i" and arg1 ~= "n" then
				if AdjustN(1) == 0 then
					return TryToReport()
				else
					return func()
				end
			end
		end
	end

	return box
end

--- DOCME
-- @treturn function A
-- @treturn table T
function M.MakePerObjectCallList ()
	local object_to_list, list = meta.WeakKeyed()

	return function(func, object)
		local curf = object_to_list[object]

		if curf then -- not the very first function?
			if not list then -- second function?
				list, BoxesStash[#BoxesStash + 1] = { curf(BoxNonce, "extract") }, curf

				object_to_list[object] = function(arg1, arg2)
					if arg1 == "i" then
						return list[arg2]
					end

					local expected_n = #list
					local n = AdjustN(expected_n)

					if arg1 == "n" then
						return n
					end

					for i = 1, n do
						list[i]()
					end

					if n < expected_n then
						TryToReport()
					end
				end
			end

			list[#list + 1] = func
		else -- first one
			object_to_list[object] = Box(func)
		end
	end, object_to_list
end

local Dispatcher = {}

Dispatcher.__index = Dispatcher

--- DOCME
-- @treturn function A
function Dispatcher:GetAdder ()
    return self.m_add_to_list
end

--- DOCME
-- @param object
-- @param ...
function Dispatcher:DispatchForObject (object, ...)
    local func = self.m_object_to_list[object]

    if func then
        func(...)
    end
end

--- DOCME
-- @param object
-- @treturn iterator Y
function Dispatcher:IterateFunctionsForObject (object)
    return _IterateCallList_(self.m_object_to_list[object])
end

---
-- @treturn Dispatcher X
function M.NewDispatcher ()
    local dispatcher = {}

    dispatcher.m_add_to_list, dispatcher.m_object_to_list = _MakePerObjectCallList_()

	return setmetatable(dispatcher, Dispatcher)
end

-- List iterator body
local function AuxList (list, index)
	if not index then
		if list and (not Limit or Count < Limit) then
			return 0, list(BoxNonce, "get")
		end
	elseif index > 0 then
		return index - 1, list("i", index)
	end
end

--- DOCME
-- @treturn iterator X
function M.IterateCallList (list)
	return AuxList, list, list and list("n")
end

--- DOCME
-- @uint limit
function M.SetActionLimit (limit)
	assert(type(limit) == "number" and limit > 0, "Invalid limit")

	Limit = limit
end

_IterateCallList_ = M.IterateCallList
_MakePerObjectCallList_ = M.MakePerObjectCallList

return M