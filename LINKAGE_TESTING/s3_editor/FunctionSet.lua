--- Bundles of related functions.
--
-- Inheritance is supported, with functions being strung together in sequence if they share
-- the same name. This somewhat resembles behaviors found in aspect-oriented programming and
-- Common Lisp's generic functions; it seems to nicely fit an assortment of editor-side game
-- object logic.

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
local error = error
local getmetatable = getmetatable
local pairs = pairs
local pcall = pcall
local rawequal = rawequal
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")

-- Cached module references --
local _GetState_

-- Exports --
local M = {}

--
--
--

local Sets = {}

local function AuxFindName (instance)
	local mt = getmetatable(instance)

	for name, set in pairs(Sets) do
		if rawequal(set, mt) then
			return _GetState_(name)
		end
	end
end

---
-- @param instance
-- @return If _instance_ has a metatable created by @{New}, its name as supplied in the
-- **_name** parameter; otherwise, **nil**.
-- @see GetStateFromInstance
function M.GetNameFromInstance (instance)
	return (AuxFindName(instance)) -- ensure nil if missing
end

local State = {}

--- Get the state associated with a set.
--
-- If it already exists, the state is returned.
--
-- Failing that, we request any **state** that was provided as an option to @{New}.
--
-- If found, it is called as `result = state{ name = name }`. If _result_ is non-**nil** (the
-- modified table, for instance), this becomes the state.
--
-- Otherwise, the state is assigned a new empty table.
--
-- **N.B.** This may be called within **init**, cf. @{New}, with the same provisos.
-- @param name Name of set.
-- @return State.
function M.GetState (name)
	local state = State[name]

	if state == nil then
		local make = assert(Sets[name], "Set not found")("get_state")
		local result = make{ name = name }

		state = result == nil and {} or result -- allow for result of false

		State[name] = state
	end

	return state
end

---
-- @param instance
-- @return If _instance_ has a metatable created by @{New}, the state returned by @{GetState};
-- otherwise, **nil**.
-- @see GetNameFromInstance
function M.GetStateFromInstance (instance)
	local name, state = AuxFindName(instance)

	if name ~= nil then
		state = _GetState_(name)
	end

	return state
end

local function AddFunctionDirectly (def, name, func)
	def[name] = func
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

local function PrependFunction (def, name, func, proto)
	local arr = adaptive.Append(nil, func)

	for _, ev in PrototypeEntry(proto, name) do
		arr = adaptive.Append(arr, ev)
	end

	def[name] = arr
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

local function AddNewFunctions (def, funcs, add, proto)
	for k, v in pairs(funcs) do
		add(def, k, v, proto)
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

--- Instantiate a **FunctionSet**.
-- @param Set name, which may be any non-**nil** or -NaN value.
-- @ptable funcs Key-value pairs, with each value being a function and the key its name.
-- These will be added under the same keys in the definition, according to certain options.
-- @ptable[opt] Creation options.
--
-- The name of a previously defined set may be supplied under **prototype**, in which case
-- its functions will be incorporated into the new set. A prototype may also be accompanied
-- by **before** and **instead** tables, described in what follows.
--
-- In the absence of a name clash, either the function in the prototype or the one in _params_
-- &mdash;whichever actually exists&mdash;will be added to the new set.
--
-- Otherwise, the two functions are usually sequenced, i.e. the final function will invoke
-- one then the other. A function found in _params_ comes after its prototype counterpart; a
-- function in **before** will precede it. It is fine to supply either or both. (**N.B.**
-- Prototype entries might themselves be sequences. For composition purposes these are
-- treated as a unit.)
--
-- A function found in **instead**, on the other hand, is used in place of the prototype's
-- entry. An "instead" name may not also belong to "before" or "after".
--
-- If a prototype has no function with a given name, the composition logic interprets it as
-- providing one that does nothing.
--
-- A **state** function may be made available for @{GetState}.
--
-- If an **init** function is provided, it is called as `init(name, def)` once the definition
-- _def_ has been established, e.g. to modify _def_. This might error, so _def_ is not yet
-- registered (and thus available as a prototype).
-- @treturn table Set definition, suitable as a methods table.
function M.New (name, funcs, opts)
	assert(name ~= nil and name == name, "Invalid name")
	assert(not Sets[name], "Name already in use")
	assert(type(funcs) == "table", "Invalid params")
	assert(opts == nil or type(opts) == "table", "Invalid params")

	local def, before, init, instead, pname, state = {}

	if opts then
		before, init, instead, pname, state = opts.before, opts.init, opts.instead, opts.prototype, opts.state
	end

	if pname == nil then
		assert(not before, "Prototype must be available for `before` calls")
		assert(not instead, "Prototype must be available for `instead` calls")

		AddNewFunctions(def, funcs, AddFunctionDirectly)
	else
		local proto, pready = assert(Sets[pname], "Prototype not found")()

		assert(pready, "Prototype still being initialized")

		if instead then
			for k, v in pairs(instead) do
				assert(not (before and before[k] ~= nil), "Entry in `instead` also in `before`")
				assert(funcs[k] ~= nil, "Entry in `instead` also in main list")

				def[k] = v
			end
		end

		if before then
			for k, v in pairs(before) do
				PrependFunction(def, k, v, proto)
			end
		end

		AddNewFunctions(def, funcs, AppendFunction, proto)
		MergePrototype(def, proto)
	end

	local ready

	local function with_def (what)
		if what ~= "get_state" then
			return def, ready
		else
			local result = state

			state = nil

			return result
		end
	end

	Sets[name] = with_def -- add provisionally for GetState()...

	if init then
		local ok, err = pcall(init, name, def)

		if not ok then
			Sets[name], State[name] = nil -- ...but remove if something went wrong

			error(err)
		end
	end

	ready = true

	return def
end

_GetState_ = M.GetState

return M