--- This module provides utilities for components.

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
local next = next
local pairs = pairs
local rawequal = rawequal
local remove = table.remove
local tostring = tostring
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local meta = require("tektite_core.table.meta")

-- Cached module references --
local _CanAddToObject_
local _RemoveFromObject_

-- Exports --
local M = {}

--
--
--

local RequiredTypeCache = {} -- allow lock and ref ops in add

local Types = {}

local function AuxGatherRequiredTypes (required_types, ctype)
    required_types[ctype] = true

    local info = Types[ctype]
    local reqs = info and info.requirements

    if reqs then
        for k in adaptive.IterSet(reqs) do
            if not required_types[k] then
                AuxGatherRequiredTypes(required_types, k)
            end
        end
    end
end

local function AuxIterRequiredTypes_Keep (types, k)
	k = next(types, k)

	if k ~= nil then
		return k
	else 
		RequiredTypeCache[#RequiredTypeCache + 1] = types
	end
end

local function AuxIterRequiredTypes_Wipe (types, k)
	k = next(types, k)

	if k ~= nil then
		types[k] = nil

		return k
	else 
		RequiredTypeCache[#RequiredTypeCache + 1] = types
	end
end

local function RequiredTypes (ctype, how) -- n.b. set up by CanAddToObject()
	local required_types = remove(RequiredTypeCache) or {}

	if how ~= "reuse" then -- reusing already-gathered result?
		AuxGatherRequiredTypes(required_types, ctype)
	end

	return how == "keep" and AuxIterRequiredTypes_Keep or AuxIterRequiredTypes_Wipe, required_types, nil
end

local Lists = meta.WeakKeyed()

--- Add a component to an object.
--
-- TODO: on_add(object, new_type)
-- @param object
-- @param ctype Component type.
-- @treturn boolean The addition succeeded.
-- @see CanAddToObject
function M.AddToObject (object, ctype)
    local can_add = _CanAddToObject_(object, ctype)

    if can_add then
        local list = Lists[object]

        for rtype in RequiredTypes(ctype) do
            local info = Types[rtype]
            local on_add = info and info.add

            if on_add then
                on_add(object, rtype)
            end

            list = adaptive.AddToSet(list, rtype)
        end

        Lists[object] = list
    end

    return can_add
end

-- TODO: handle calling Lock, etc. from on_add, so those don't trounce 

local function AllowedByCurrentList (list, object, ctype)
    for comp in adaptive.IterSet(list) do
        local info = Types[comp]
        local on_allow_add = info and info.allow_add

        if on_allow_add then
            local ok, err = on_allow_add(ctype, object, comp)

            if not ok then
                return false, err
            end
        end
    end

    return true
end

local function EnsureRequiredTypesInfo (info)
    local req_list = info and info.requirement_list

    if req_list then -- not yet resolved?
        local reqs, rlist = {}, info.requirement_list -- save list in case of error...

        info.requirement_list = nil -- ...but remove it to guard against recursion

        for i = 1, #req_list do
            local rtype = req_list[i]
            local rinfo = Types[rtype]

            if rinfo == nil or not EnsureRequiredTypesInfo(rinfo) then
                info.requirement_list = rlist -- failure, so restore list

                return false
            else
                reqs[rtype] = true
            end
        end

        info.requirements = reqs
    end

    return true
end

--- Check whether the object can accept the component.
--
-- TODO: allow_add(new_type, object, existing_type)...
-- @param object
-- @param ctype Component type.
-- @return[1] **true**, meaning the addition would succeed.
-- @return[2] **false**, indicating failure.
-- @treturn string Failure reason.
-- @see AddToObject
function M.CanAddToObject (object, ctype)
    local list, info = Lists[object], Types[ctype]

    if info == nil then
        return false, "Type not registered"
    elseif adaptive.InSet(list, ctype) then
        return false, "Already present"
    elseif not EnsureRequiredTypesInfo(info) then -- resolve any requirements on first request
        return false, "Required type not registered"
    else
        if info and info.requirements then -- ensure we can add required components, if necessary...
            for rtype in pairs(info.requirements) do
                if not adaptive.InSet(list, rtype) then
                    local ok, err = AllowedByCurrentList(list, object, rtype)

                    if not ok then
                        return false, err
                    end
                end
            end
        end

        return AllowedByCurrentList(list, object, ctype) -- ...as well as the requested one
    end

    return true
end

---
-- @param object
-- @param ctype Component type.
-- @treturn boolean Does _ctype_ belong to _object_?
function M.FoundInObject (object, ctype)
    for comp in adaptive.IterSet(Lists[object]) do
        if rawequal(comp, ctype) then
            return true
        end
    end

    return false
end

--- Get the list of interfaces implemented by a component.
-- @param ctype
-- @tparam[opt] table out If provided, this will be populated and used as the return value.
--
-- The final size will be trimmed down to the number of interfaces, if necessary.
-- @treturn {Interface,...} Array of interfaces.
-- @see GetInterfacesForObject, Implements, RegisterType
function M.GetInterfacesForComponent (ctype, out)
    out = out or {}

    local info, n = Types[ctype], 0

    assert(info ~= nil, "Type not registered")

	for i = 1, #(info or "") do
		out[n + 1], n = info[i], n + 1
	end

    for i = #out, n + 1, -1 do
        out[i] = nil
    end

    return out
end

local InterfaceGuards, AddGeneration, IsAdding = meta.WeakKeyed(), 0

local function AddOnFirstAppearance (out, interface, n)
	if InterfaceGuards[interface] ~= AddGeneration then
		InterfaceGuards[interface], IsAdding = AddGeneration, true
		out[n + 1], n = interface, n + 1
	end

	return n
end

local function FinishAdding ()
	if IsAdding then
		AddGeneration, IsAdding = AddGeneration + 1
	end
end

--- Get the list of interfaces implemented by an object's components.
-- @param object
-- @tparam[opt] table out If provided, this will be populated and used as the return value.
--
-- The final size will be trimmed down to the number of interfaces, if necessary.
-- @treturn {Interface,...} Array of interfaces, with duplicates removed.
-- @see Implements, RegisterType
function M.GetInterfacesForObject (object, out)
    out = out or {}

    local n = 0

    for comp in adaptive.IterSet(Lists[object]) do
        local info = Types[comp]

        for i = 1, #(info or "") do
			n = AddOnFirstAppearance(out, info[i], n)
        end
    end

	FinishAdding()

    for i = #out, n + 1, -1 do
        out[i] = nil
    end

    return out
end

--- Get the list of component types belonging to an object.
-- @param object
-- @tparam[opt] table out If provided, this will be populated and used as the return value.
--
-- The final size will be trimmed down to the number of components, if necessary.
-- @treturn {ComponentType,...} Array of types.
-- @see AddToObject, RegisterType
function M.GetListForObject (object, out)
    out = out or {}

    local n = 0

    for comp in adaptive.IterSet(Lists[object]) do
        out[n + 1], n = comp, n + 1
    end

    for i = #out, n + 1, -1 do
        out[i] = nil
    end

    return out
end

local function AuxImplements (info, what)
    for i = 1, #(info or "") do
        if rawequal(info[i], what) then
            return true
        end
    end
end

---
-- @param ctype Component type.
-- @param what Interface.
-- @treturn boolean Does _ctype_ implement _what_?
function M.Implements (ctype, what)
    local info = Types[ctype]

    assert(info ~= nil, "Type not registered")

    return AuxImplements(info, what) or false -- coerce nil to false
end

---
-- @param object
-- @param what Interface.
-- @treturn boolean Does _object_ have a component that implements _what_?
function M.ImplementedByObject (object, what)
    for comp in adaptive.IterSet(Lists[object]) do
        if AuxImplements(Types[comp], what) then
            return true
        end
    end

    return false
end

---
-- @param ctype Component type.
-- @treturn boolean Has _ctype_ been registered?
function M.IsRegistered (ctype)
	return Types[ctype] ~= nil
end

local Locks = meta.WeakKeyed()

local Inf = 1 / 0

local function NotLocked (locks, ctype)
	local count = locks[ctype] or 0

    return 1 / count ~= 0
end

--- Permanently lock a component into this object.
--
-- This will override any reference counting on the component.
-- @param object
-- @param ctype Component type.
-- @see RefInObject, RemoveAllFromObject, RemoveFromObject, UnrefInObject
function M.LockInObject (object, ctype)
    local locks = Locks[object] or {}

    if NotLocked(locks, ctype) then
		for rtype in RequiredTypes(ctype) do
			locks[rtype] = Inf
		end
    end

	Locks[object] = locks
end

--- Purge some internal non-duplication state.
function M.PurgeInterfaceGuards ()
	for k in pairs(InterfaceGuards) do
		InterfaceGuards[k] = nil
	end
end


--- Increment the reference count (starting at 0) on a component. While this count is greater
-- than 0, the component is locked.
--
-- This is a no-op after @{LockInObject} has been called.
-- @see RemoveAllFromObject, RemoveFromObject, UnrefInObject
function M.RefInObject (object, ctype)
    local locks = Locks[object] or {}
	
	if NotLocked(locks, ctype) then
        for rtype in RequiredTypes(ctype) do
            locks[rtype] = (locks[rtype] or 0) + 1 -- if infinity, left as-is
        end
    end

	Locks[object] = locks
end

local Actions = { add = true, allow_add = true, remove = true }

local function IsTable (_, object)
	return type(object) == "table"
end

--- Register a new component type.
-- @tparam ?|table|string As a string, the name of the component.
--
-- Otherwise, a table with one or more of the following:
-- * **name**: The aforesaid name. (Required.)
-- * **actions**: Table that may contain **add**, **allow\_add**, and **remove** functions. (Optional.)
-- * **interfaces**: Array of interfaces implemented by this component. (Optional.)
-- * **requires**: Array of component types that an object must also contain in order to have
-- this component. These need not have been registered yet. (Optional.)
-- @return Name, as a convenience.
-- @see AddToObject, CanAddToObject, RemoveFromObject
function M.RegisterType (params)
    local ptype, name, actions, interfaces, requires = type(params)

    if ptype == "string" then
        name = params
    else
        assert(ptype == "table", "Expected string or table params")

        name, actions, interfaces, requires = params.name, params.actions, params.interfaces, params.requires
    end

    assert(name ~= nil, "Expected component name")

    if actions or interfaces or requires then
		assert(Types[name] == nil, "Name already in use")
        assert(actions == nil or type(actions) == "table", "Invalid actions")

        local ctype, n = {}, 0

        for k, v in adaptive.IterSet(actions) do
            assert(Actions[k], "Unsupported action")

			if rawequal(v, "is_table") then
				assert(k == "allow_add", "Predicate only used on `allow_add` action")

				ctype[v] = IsTable
			else
				ctype[k] = v
			end
        end

        ctype.requirement_list = adaptive.CopyArray(requires) -- put any requirements here for now, but resolve on first use

        for _, name in adaptive.IterArray(interfaces) do
			n = AddOnFirstAppearance(ctype, name, n)
        end

		FinishAdding()

        Types[name] = ctype
    else
		assert(not Types[name], "Complex type already registered") -- previous false okay

        Types[name] = false
    end

	return name
end

local function AuxRemove (object, comp)
    local info = Types[comp]
    local on_remove = info and info.remove

    if on_remove then
        on_remove(object, comp)
    end
end

--- Remove any components from an object that are not locked or referenced, cf. @{RemoveFromObject}.
-- @param object
-- @see LockInObject, RefInObject
function M.RemoveAllFromObject (object)
    local locks = Locks[object]

    if locks then
        local list = Lists[object]

        for comp in adaptive.IterSet(list) do
            if not locks[comp] then
                AuxRemove(object, comp)

                list = adaptive.RemoveFromSet(list, comp)
            end
        end

        Lists[object] = list
    else
        for comp in adaptive.IterSet(Lists[object]) do
            AuxRemove(object, comp)
        end

        Lists[object] = nil
    end
end

local ToRemove = {}

--- Remove a component from an object, if not locked or referenced.
--
-- TODO: remove(object, removed_type)
-- @param object
-- @param ctype Component type.
-- @treturn boolean The remove succeeded, i.e. the component existed and was removable?
-- @see LockInObject, RefInObject, RemoveAllFromObject
function M.RemoveFromObject (object, ctype)
    assert(Types[ctype] ~= nil, "Type not registered")

	local locks = Locks[object]

    if locks and locks[ctype] then
        return false
    end

    local list = Lists[object]
    local exists = adaptive.InSet(list, ctype)

    if exists then
        for comp in adaptive.IterSet(object) do
            ToRemove[comp] = false
        end

        ToRemove[ctype] = true

        repeat
            local any = false

            for dtype, visited in pairs(ToRemove) do
                local info = not visited and Types[dtype]
                local reqs = info and info.requirements

                if reqs then
                    for k in pairs(reqs) do
                        if ToRemove[k] then -- do we depend on something that gets removed?
                            ToRemove[dtype], any = true, true -- must remove self as well

                            break
                        end
                    end
                end
            end
        until not any -- nothing else affected?

        for comp, affected in pairs(ToRemove) do
            if affected then
                AuxRemove(object, comp)

                list = adaptive.RemoveFromSet(list, comp)
            end

            ToRemove[comp] = nil
        end

        Lists[object] = list
    end

    return exists
end

--- Decrement the reference count for a component, unlocking it if the count falls to 0.
--
-- This is a no-op after @{LockInObject} has been called.
--
-- In a well-behaved implementation, this must follow a previous `RefInObject(object, ctype)` call.
-- @see LockInObject, RemoveAllFromObject, RemoveFromObject
function M.UnrefInObject (object, ctype)
    local locks = Locks[object]

	if locks and NotLocked(locks, ctype) then
		for rtype in RequiredTypes(ctype, "keep") do -- detect improper usage, e.g. unref'ing required type directly, keeping results around
			if not locks[rtype] then
				assert(false, "Bad ref count for component: " .. tostring(rtype))
			end
		end

        for rtype in RequiredTypes(ctype, "reuse") do -- use validated results from previous loop, wiping them along the way
			local new_count = locks[rtype] - 1 -- if infinity, left as-is

            locks[rtype] = new_count > 0 and new_count
        end
    end

	Locks[object] = locks
end

_CanAddToObject_ = M.CanAddToObject
_RemoveFromObject_ = M.RemoveFromObject

return M