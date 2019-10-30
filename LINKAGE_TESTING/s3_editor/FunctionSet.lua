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
-- Otherwise, if the parameters to @{New} contain a **_state** member, this is called as
-- `state{ name = name }`. If the table's **result** member is non-**nil** afterward, that
-- becomes the state; otherwise, it will be **false**.
--
-- Failing that, an empty table is created.
--
-- **N.B.** This may be called within **_init**, cf. @{New}, with the same provisos.
-- @param name Name of set.
-- @return State.
function M.GetState (name)
	local state = State[name]

	if state == nil then
		local set = assert(Sets[name], "Set not found")
		local make = set._state

		if make then
			local work = { name = name }

			make(work)

			state, set._state = work.result or false
		else
			state = {}
		end
	end

	State[name] = state

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
	local list = proto._list
	local entry = list and list[name] or proto[name] -- n.b. fallthrough when list[name] nil

	return adaptive.IterArray(entry)
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
	local list

	for k, v in pairs(def) do
		if type(v) == "table" then
			list = list or {} -- only create if needed

			local function wrapped (event)
				for i = 1, #v do
					v[i](event)
				end
			end

			wrapped[k], def[k] = wrapped
		end
	end

	def._list = list
end

local Reserved = { _before = true, _instead = true, _list = true, _name = true, _prototype = true }

local function AddNewFunctions (def, params, add, proto)
	for k, v in pairs(params) do
		if not Reserved[k] then
			add(def, k, v, proto)
		end
	end

	WrapCallLists(def)
end

local function MergePrototype (def, proto)
	for k, v in pairs(proto) do
		if k == "_list" and def._list then
			MergePrototype(def._list, v) -- will both be tables without own _list member
		elseif def[k] == nil then -- not defined in new type, including not extending anything in prototype
			def[k] = v
		end
	end
end

--- Instantiate a **FunctionSet**.
-- @ptable params Functions and parameters for the set.
--
-- String keys beginning with an underscore are reserved. In particular, **_name** is
-- required and will be used as the name of the set.
--
-- The remainder of the params are key-value pairs, with the value being a function and the
-- key its name. These will be added under the same names in the definition.
--
-- The name of a previously defined set may be supplied under **_prototype**, in which case
-- the definition will also incorporate the functions in that set. A prototype may also be
-- accompanied by **_before** and **_instead** tables, described in what follows.
--
-- In the absence of a name clash, either the prototype's function or the new one, whichever
-- actually exists, will be added to the definition.
--
-- Otherwise, the two functions are usually sequenced, i.e. the final function will invoke
-- one then the other. By default, new functions come after those from the prototype; a
-- function found under the same name in **_before** will precede them. It is fine to supply
-- either or both. (**N.B.** Prototype entries might themselves be sequences. For composition
-- purposes they are interpreted as a unit.)
--
-- Any functions found in **_instead**, on the other hand, will override anything coming from
-- the prototype. A name in **_instead** may not also be in the "before" or "after" entries.
--
-- A prototype might not provide a function found in any of the provided tables. In this
-- case, the aforementioned "after", "before", and "instead" logic behave as if given a
-- do-nothing function.
--
-- A **_state** function may be made available for @{GetState}.
--
-- If an **_init** function is provided, it is called as `init(name, def)` once the rest of the
-- definition has been established. This might error, so _def_ is not yet registered (and
-- thus available as a prototype); `GetState(name)` is allowed, though.
-- @treturn table Set definition, suitable as a methods metatable.
--
-- Its contents may be modified, aside from values with reserved keys.
-- @return _params_.**name**, as a convenience.
function M.New (params)
	assert(type(params) == "table", "Invalid params")

	local name = params._name

	assert(name ~= nil and name == name, "Invalid name")
	assert(not Sets[name], "Name already in use")

	local before, instead, pname, def = params._before, params._instead, params._prototype, {}

	if pname == nil then
		assert(not before, "Prototype must be available for `before` calls")
		assert(not instead, "Prototype must be available for `instead` calls")

		AddNewFunctions(def, params, AddFunctionDirectly)
	else
		local proto = assert(Sets[pname], "Prototype not found")

		assert(proto._initialized, "Prototype still being initialized")

		if instead then
			assert(not instead._state, "Instead list may not contain `state` call")

			for k, v in pairs(instead) do
				assert(not (before and before[k] ~= nil), "Entry in `instead` also in `before`")
				assert(params[k] ~= nil, "Entry in `instead` also in main list")

				def[k] = v
			end
		end

		if before then
			assert(not before._state, "Before list may not contain `state` call")

			for k, v in pairs(before) do
				PrependFunction(def, k, v, proto)
			end
		end

		AddNewFunctions(def, params, AppendFunction, proto)
		MergePrototype(def, proto)
	end

	Sets[name] = def -- add provisionally for GetState()...

	local init = def._init

	if init then
		local ok, err = pcall(init, name, def)

		if not ok then
			Sets[name] = nil -- ...but remove if something went wrong

			error(err)
		end
	end

	def._initialized = true

	return def, name
end

_GetState_ = M.GetState

return M