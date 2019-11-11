--- This module provides various metatable operations.

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
local getmetatable = getmetatable
local pairs = pairs
local rawequal = rawequal
local setmetatable = setmetatable
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")

-- Cached module references --
local _FullyWeak_
local _WeakKeyed_

-- Exports --
local M = {}

--
--
--

local Cached, Augmented

local function Copy (t, err)
	assert(type(t) == "table", err)

	local dt = {}

	for k, v in pairs(t) do
		assert(type(v) == "function", "Non-function property")

		dt[k] = v
	end

	return dt
end

--- DOCME
-- @ptable object
-- @ptable extension
function M.Augment (object, extension)
	if not Cached then
		Augmented, Cached = _FullyWeak_(), _WeakKeyed_()
	end

	local mt = getmetatable(object)

	assert(type(extension) == "table", "Extension must be a table")
	assert(mt == nil or type(mt) == "table", "Metatable missing or inaccessible")
	assert(not Augmented[object], "Object's metatable already augmented")

	local cached = Cached[mt]

	if cached then
		assert(rawequal(cached, extension), "Attempt to augment object with different extension")
	else
		local list, old_index, old_newindex = {}, mt and mt.__index, mt and mt.__newindex

		for k, v in pairs(extension) do
			if k ~= "__rprops" and k ~= "__wprops" then
				list[k] = v
			end
		end

		setmetatable(list, getmetatable(extension))

		local is_table_oi, index = type(old_index) == "table"

		if extension.__rprops then
			local rprops = Copy(extension.__rprops, "Invalid readable properties (__rprops)")

			function index (t, k)
				local prop = rprops[k]

				if prop then
					local what, res = prop(t, k)

					if what == "use_index_k" then
						k = res
					elseif what ~= "use_index" then
						return what
					end
				end

				local item = list[k]

				if item ~= nil then
					return item
				elseif is_table_oi then
					return old_index[k]
				elseif old_index then
					return old_index(t, k)
				end
			end
		elseif old_index then
			function index (t, k)
				local item = list[k]

				if item ~= nil then
					return item
				elseif is_table_oi then
					return old_index[k]
				else
					return old_index(t, k)
				end
			end
		else
			index = list
		end

		local is_table_oni, newindex = type(old_newindex) == "table"

		if extension.__wprops then
			local wprops = Copy(extension.__wprops, "Invalid writeable properties (__wprops)")

			function newindex (t, k, v)
				local prop = wprops[k]

				if prop then
					local what, res1, res2 = prop(t, v, k)

					if what == "use_newindex_k" then
						k = res1
					elseif what == "use_newindex_v" then
						v = res1
					elseif what == "use_newindex_kv" then
						k, v = res1, res2
					elseif what ~= "use_newindex" then
						return
					end
				end

				if is_table_oni then
					old_newindex[k] = v
				elseif old_newindex then
					old_newindex(t, k, v)
				end
			end
		else
			newindex = old_newindex
		end

		local new = { __index = index, __newindex = newindex }

		setmetatable(object, new)

		Augmented[object], Cached[new] = new, extension
	end
end

local function PrototypeEntry (proto, name)
	return adaptive.IterArray(proto[name])
end

local function AppendFunction (def, name, func, proto)
	local arr = def[name]

	if not arr then -- prototype calls not already merged by "before" logic?
		for _, ev in PrototypeEntry(proto, name) do
			arr = adaptive.Append(arr, ev)
		end
	end

	def[name] = adaptive.Append(arr, func)
end

local function WrapCallLists (def)
	for k, v in pairs(def) do
		if type(v) == "table" then
			def[k] = function(event)
				for i = 1, #v do
					v[i](event)
				end
			end
		end
	end
end

local function AppendFunctions (def, funcs, proto)
	for k, v in pairs(funcs) do
		AppendFunction(def, k, v, proto)
	end

	WrapCallLists(def)
end

local function MergePrototype (def, proto)
	for k, v in pairs(proto) do
		if def[k] == nil then
			def[k] = v
		end
	end
end

local function PrependFunction (def, name, func, proto)
	local arr = adaptive.Append(nil, func)

	for _, ev in PrototypeEntry(proto, name) do
		arr = adaptive.Append(arr, ev)
	end

	def[name] = arr
end

--- Bundle related functions. TODO: clean this all up
--
-- Inheritance is supported, with functions being strung together in sequence if they share
-- the same name. This somewhat resembles behaviors found in aspect-oriented programming and
-- Common Lisp's generic functions; it seems to nicely fit an assortment of editor-side game
-- object logic.
-- @ptable funcs Key-value pairs, with each value being a function and the key its name.
-- These will be added under the same keys in the definition, according to the contents
-- of _prototype_ and _lists_.
-- @ptable prototype
-- @ptable[opt] lists Additional function lists.
--
-- The name of a previously defined set may be supplied under **prototype**, in which case
-- its functions will be incorporated into the new set. A prototype may also be accompanied
-- by **before** and **instead** tables, described in what follows.
--
-- In the absence of a name clash, either the function in _funcs_ or the one in _prototype_
-- &mdash;whichever actually exists&mdash;will be added to the new set.
--
-- Otherwise, the two functions are usually sequenced, i.e. the final function will invoke
-- one then the other. A function found in _params_ comes after its prototype counterpart; a
-- function in **before** will precede it. It is fine to supply either or both. (**N.B.**
-- Prototype entries might themselves be sequences. For composition purposes these are
-- treated as a unit.)
--
-- A function found in **instead**, on the other hand, is used in place of the entry from
-- _prototype_. An "instead" name may not also belong to "before" or "after".
--
-- If _prototype_ has no function with a given name, the composition logic interprets it as
-- providing one that does nothing.
-- @treturn table Combined function list, suitable as a methods table.
function M.CombineFunctionLists (funcs, prototype, lists)
	assert(type(funcs) == "table", "Invalid main list")
	assert(type(prototype) == "table", "Invalid prototype")
	assert(lists == nil or type(lists) == "table", "Invalid additional lists")

	local def, around, before, instead = {}

	if lists then
		around, before, instead = lists.around, lists.before, lists.instead
	end

	if around then
		for k, v in pairs(around) do
			local pfunc = assert(prototype[k], "Entry in `around` not found in prototype")

			def[k] = function(...)
				return v(pfunc, ...)
			end
		end
	end

	if instead then
		for k, v in pairs(instead) do
			assert(not (around and around[k] ~= nil), "Entry in `instead` also in `around`")
			assert(not (before and before[k] ~= nil), "Entry in `instead` also in `before`")
			assert(not funcs[k], "Entry in `instead` also in main list")

			def[k] = v
		end
	end

	if before then
		for k, v in pairs(before) do
			PrependFunction(def, k, v, prototype)
		end
	end

	AppendFunctions(def, funcs, prototype)
	MergePrototype(def, prototype)

	return def
end

local Choices = { k = {}, v = {}, kv = {} }

for mode, mt in pairs(Choices) do
	mt.__metatable, mt.__mode = true, mode
end

--- Builds a new fully weak table, with a fixed metatable.
-- @treturn table Table.
-- @see WeakKeyed, WeakValued
function M.FullyWeak (choice)
	return setmetatable({}, Choices.kv)
end

--- Builds a new weak-keyed table, with a fixed metatable.
-- @treturn table Table.
-- @see FullyWeak, WeakValued
function M.WeakKeyed (choice)
	return setmetatable({}, Choices.k)
end

--- Builds a new weak-valued table, with a fixed metatable.
-- @treturn table Table.
-- @see FullyWeak, WeakKeyed
function M.WeakValued (choice)
	return setmetatable({}, Choices.v)
end

_FullyWeak_ = M.FullyWeak
_WeakKeyed_ = M.WeakKeyed

return M