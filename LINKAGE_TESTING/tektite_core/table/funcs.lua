--- This module provides various utilities that make or operate on tables.

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
local ipairs = ipairs
local pairs = pairs
local type = type

-- Modules --
local wipe = require("tektite_core.array.wipe")

-- Cached module references --
local _Map_

-- Exports --
local M = {}

--
--
--

-- Helper to pass value through unaltered
local function PassThrough (var)
	return var
end

local function CheckOpts (opts)
	assert(opts == nil or type(opts) == "table", "Invalid options")

	return opts and opts.out or {}
end

--- Shallow-copies a table.
--
-- @todo Account for cycles, table as key; link to Map
-- @ptable t Table to copy.
-- @ptable[opt] opts TODO!
-- @treturn table Copy.
function M.Copy (t, opts)
    return _Map_(t, PassThrough, opts)
end

--- Copies all values with the given keys into a second table with those keys.
-- @ptable t Table to copy.
-- @ptable keys Key array.
-- @ptable[opt] opts TODO!
-- @treturn table Copy.
function M.CopyK (t, keys, opts)
    local dt = CheckOpts(opts)

    for _, k in ipairs(keys) do
        dt[k] = t[k]
    end

    return dt
end

--- Finds a match for a value in the table. The **"eq"** metamethod is respected by
-- the search.
-- @ptable t Table to search.
-- @param value Value to find.
-- @bool is_array Search only the array part (up to a **nil**, in order)?
-- @return Key belonging to a match, or **nil** if the value was not found.
function M.Find (t, value, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v == value then
			return k
		end
	end
end

--- Array variant of @{Find}, which searches each entry up to the first **nil**,
-- quitting if the index exceeds _n_.
-- @ptable t Table to search.
-- @param value Value to find.
-- @uint n Limiting size.
-- @treturn uint Index of first match, or **nil** if the value was not found in the range.
function M.Find_N (t, value, n)
	for i, v in ipairs(t) do
		if i > n then
			return
		elseif v == value then
			return i
		end
	end
end

--- Finds a non-match for a value in the table. The **"eq"** metamethod is respected
-- by the search.
-- @ptable t Table to search.
-- @param value_not Value to reject.
-- @bool is_array Search only the array part (up to a **nil**, in order)?
-- @return Key belonging to a non-match, or **nil** if only matches were found.
-- @see Find
function M.FindNot (t, value_not, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v ~= value_not then
			return k
		end
	end
end

--- Performs an action on each item of the table.
-- @ptable t Table to iterate.
-- @callable func Visitor function, called as
--    func(v, arg)
-- where _v_ is the current value and _arg_ is the parameter. If the return value
-- is not **nil**, iteration is interrupted and quits.
-- @bool is_array Traverse only the array part (up to a **nil**, in order)?
-- @param arg Argument to _func_.
-- @return Interruption result, or **nil** if the iteration completed.
function M.ForEach (t, func, is_array, arg)
	local result

	for _, v in (is_array and ipairs or pairs)(t) do
		result = func(v, arg)

		if result ~= nil then
			break
		end
	end

	return result
end

--- Key-value variant of @{ForEach}.
-- @ptable t Table to iterate.
-- @callable func Visitor function, called as
--    func(k, v, arg)
-- where _k_ is the current key, _v_ is the current value, and _arg_ is the
-- parameter. If the return value is not **nil**, iteration is interrupted and quits.
-- @bool is_array Traverse only the array part (up to a **nil**, in order)?
-- @param arg Argument to _func_.
-- @return Interruption result, or **nil** if the iteration completed.
function M.ForEachKV (t, func, is_array, arg)
	local result

	for k, v in (is_array and ipairs or pairs)(t) do
		local result = func(k, v, arg)

		if result ~= nil then
			break
		end
	end

	return result
end

--- Builds a table's inverse, i.e. a table with the original keys as values and vice versa.
--
-- Where the same value maps to many keys, no guarantee is provided about which key becomes
-- the new value.
-- @ptable t Table to invert.
-- @ptable[opt] opts TODO!
-- @treturn table Inverse table.
function M.Invert (t, opts)
	local dt = CheckOpts(opts)

	assert(t ~= dt, "Invert: Table cannot be its own destination")

	for k, v in pairs(t) do
		dt[v] = k
	end

	return dt
end

--- Makes a set, i.e. a table where each element has value **true**. For each value in
-- _t_, an element is added to the set, with the value instead as the key.
-- @ptable t Key array.
-- @ptable[opt] opts TODO!
-- @treturn table Set constructed from array.
function M.MakeSet (t, opts)
	local dt = CheckOpts(opts)

	for _, v in ipairs(t) do
		dt[v] = true
	end

	return dt
end

-- how: Table operation behavior
-- Returns: Offset pertinent to the behavior
local function GetOffset (t, how)
	return (how == "append" and #t or 0) + 1
end

-- Resolves a table operation
-- how: Table operation behavior
-- offset: Offset reached by operation
-- how_arg: Argument specific to behavior
local function Resolve (t, how, offset, how_arg)
	if how == "overwrite_trim" then
		wipe.WipeRange(t, offset, how_arg)
	end
end

-- Maps input items to output items
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- @ptable[opt] opts TODO!
-- Returns: Mapped table
-------------------------------------------------- DOCMEMORE
function M.Map (t, map, opts)
	local dt, how, arg, how_arg = CheckOpts(opts)

	if opts then
		how, arg, how_arg = opts.how, opts.arg, opts.how_arg
	end

	if how then
		local offset = GetOffset(dt, how)

		for _, v in ipairs(t) do
			dt[offset] = map(v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(v, arg)
		end
	end

	return dt
end

-- Key array @{Map} variant
-- ka: Key array
-- map: Mapping function
-- arg: Mapping argument
-- @ptable[opt] opts TODO!
-- Returns: Mapped table
------------------------- DOCMEMORE
function M.MapK (ka, map, opts)
	local dt = CheckOpts(opts)
	local arg = opts and opts.arg

	for _, k in ipairs(ka) do
		dt[k] = map(k, arg)
	end

	return dt
end

-- Key-value @{Map} variant
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- @ptable[opt] opts TODO!
-- Returns: Mapped table
-------------------------------------------------- DOCMEMORE
function M.MapKV (t, map, opts)
	local dt, how, arg, how_arg = CheckOpts(opts)

	if opts then
		how, arg, how_arg = opts.how, opts.arg, opts.how_arg
	end

	if how then
		local offset = GetOffset(dt, how)

		for i, v in ipairs(t) do
			dt[offset] = map(i, v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(k, v, arg)
		end
	end

	return dt
end

-- Moves items into a second table
-- how, how_arg: Move behavior, argument
-- @ptable[opt] opts TODO!
-- Returns: Destination table
----------------------------------------- DOCMEMORE
function M.Move (t, opts)
	local dt, how, how_arg = CheckOpts(opts)

	if opts then
		how, how_arg = opts.how, opts.how_arg
	end

	if t ~= dt then
		if how then
			local offset = GetOffset(dt, how)

			for i, v in ipairs(t) do
				dt[offset], offset, t[i] = v, offset + 1
			end

			Resolve(dt, how, offset, how_arg)

		else
			for k, v in pairs(t) do
				dt[k], t[k] = v
			end
		end
	end

	return dt
end

_Map_ = M.Map

return M