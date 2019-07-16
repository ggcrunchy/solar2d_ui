--- This module provides some features for using entities.

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
local min = math.min
local rawequal = rawequal
local remove = table.remove
local setmetatable = setmetatable
local type = type

-- Modules --
local collect = require("tektite_core.array.collect")
local component = require("tektite_core.component")
local meta = require("tektite_core.table.meta")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

local NamedParams = {}

--- DOCME
-- @param what
-- @array names
-- @bool copy
function M.AssignMessageParameterNames (what, names, copy)
    assert(not NamedParams[what], "Message type's parameters have already been named")
    assert(type(names) == "table", "Expected array of names")

    if copy then
        local out = {}

        for i = 1, #names do
            out[i] = names[i]
        end

        names = out
    end

    NamedParams[what] = names
end

local Entity = {}

Entity.__index = Entity

--- DOCME
-- @function Entity:AddComponent
Entity.AddComponent = component.AddToObject

--- DOCME
-- @function Entity:CanAddToComponent
Entity.CanAddComponent = component.CanAddToObject

--- DOCME
-- @function Entity:GetListForObject
Entity.GetComponentList = component.GetListForObject

--- DOCME
-- @function Entity:GetInterfacesForObject
Entity.GetInterfaceList = component.GetInterfacesForObject

--- DOCME
-- @function Entity:FoundInObject
Entity.HasComponent = component.FoundInObject

--- DOCME
-- @function Entity:ImplementedByObject
Entity.Implements = component.ImplementedByObject

--- DOCME
-- @function Entity:LockInObject
Entity.LockComponent = component.LockInObject

--- DOCME
-- @function Entity:RefInObject
Entity.RefComponent = component.RefInObject

--- DOCME
-- @function Entity:RemoveAllFromObject
Entity.RemoveAllComponents = component.RemoveAllFromObject

--- DOCME
-- @function Entity:RemoveFromObject
Entity.RemoveComponent = component.RemoveFromObject

local EventCache = {}

local function Finalize (event)
    event.target:RemoveAllComponents()
end

local DisplayObjectMT = meta.Weak("k")

local function IsDisplayObject (object)
    local mt = getmetatable(object)

    if mt == nil or DisplayObjectMT[mt] then -- vanilla table or already classified
        return mt ~= nil
    else
        local stage = display.getCurrentStage()

        repeat
            object = object.parent -- TODO: snapshots, etc.

            if rawequal(object, stage) then
                DisplayObjectMT[mt] = true

                return true
            end
        until not object

        return false
    end
end

local function BeginMessage (entity, event)
    event.target = entity
end

local function DoMessage (entity, event, what)
    if IsDisplayObject(entity) then
        entity:dispatchEvent(event)
    elseif type(entity) == "table" then -- TODO: or userdata with __index
        local handler = entity[what]

        if handler then
            handler(event)
        end
    end
end

local function EndMessage (event)
    local result = event.result

    event.result, event.target = nil -- clean up in case collectible

    return result
end

--- DOCME
-- @ptable event
-- @return R
function Entity:SendEvent (event)
    assert(type(event) == "table", "Non-table event")

    local name = event.name

    assert(name ~= nil, "Missing event name")

    event.result = nil -- might never be assigned, so ensure absence

    BeginMessage(self, event)
    DoMessage(self, event, name)

    return EndMessage(event)
end

--- DOCME
-- @param what
-- @param ...
-- @return R
function Entity:SendMessage (what, ...)
    local event = remove(EventCache) or { args = {} }

    event.n, event.name = collect.CollectArgsInto(event.args, ...), what

    local args, n = event.args, event.n -- n.b. saved in case removed (cf. what follows) or stomped on
    local pnames, nparams = NamedParams[what], 0

    if pnames then
        nparams = min(n, #pnames)

        for i = 1, nparams do
            event[pnames[i]] = args[i]
        end

        event.args, event.n = nil -- not relevant due to named parameters
    end

    BeginMessage(self, event)
    DoMessage(self, event, what)

    for i = nparams, 1, -1 do
        event[pnames[i]] = nil
    end

    for i = n, 1, -1 do
        args[i] = nil -- clean up in case collectible
    end

    EventCache[#EventCache + 1], event.args = event, args

    return EndMessage(event)
end

--- DOCME
-- @function Entity:UnrefInObject
Entity.UnrefComponent = component.UnrefInObject

local Methods = meta.Weak("k")

--- DOCME
-- @param object
-- @ptable methods
-- @return _object_.
function M.Make (object, methods)
    assert(Methods[methods], "Expected result from entity.NewMethods()")

    if IsDisplayObject(object) then
        object:addEventListener("finalize", Finalize)
    end

    meta.Augment(object, methods)

    return object
end

--- DOCME
-- @param[opt] parent
-- @treturn table M
function M.NewMethods (parent)
    assert(parent == nil or Methods[parent], "Expected parent from previous call to entity.NewMethods()")

    local mt = parent and { __index = parent } or Entity
    local methods = setmetatable({}, mt)

    Methods[methods] = true

    return methods
end

local Redirects = meta.Weak("k")

--- DOCME
-- @param object
-- @tparam ?|callable|nil redirect
function M.Redirect (object, redirect)
    assert(not Redirects[object], "Already redirected")

    Redirects[object] = redirect
end

--- Convenience routine to redirect closures to objects, e.g. some sort of "self".
--
-- As an example:
--
-- `local GetObject, Nonce = entity.SelfRedirecter()`
-- 
-- `-- other code`
--
-- `local object = MakeObject()`
--
-- `local function UseObject (arg1, arg2)`
-- `  if rawequal(arg1, Nonce) then -- get self?`
-- `    return object`
-- `  else`
-- `    -- normal usage`
-- `  end`
-- `end`
--
-- `entity.Redirect(UseObject, GetObject)`
-- `entity.SendMessageTo(UseObject, "MyMessage")`
-- @treturn function Called as `result = redirect(func)`; _result_ will be `func(nonce)`.
-- @return Nonce sent as a special argument to request "self".
-- @see Redirect, SendComponentQueryTo, SendEventTo, SendMessageTo
function M.SelfRedirecter ()
    local nonce = {}

    return function(func)
        return func(nonce)
    end, nonce
end

--- DOCME
-- @param object
-- @param what
-- @param ...
-- @return X
-- @see SendEventTo, SendMessageTo
function M.SendComponentQueryTo (object, what, ...)
    local redirect = Redirects[object]

    if redirect then
        object = redirect(object)
    end

	if what == "get_component_list" then
		return component.GetListForObject(object)
	elseif what == "get_interface_list" then
		return component.GetInterfacesForObject(object)
	elseif what == "has_component" then
		return component.FoundInObject(object, ...)
	elseif what == "implements" then
		return component.ImplementedByObject(object, ...)
	else
		return nil
	end
end

--- DOCME
-- @param object
-- @ptable event
-- @return X
-- @see SendComponentQueryTo, SendEventTo
function M.SendEventTo (object, event)
    local redirect = Redirects[object]

    if redirect then
        object = redirect(object)
    end

    return Entity.SendEvent(object, event)
end

--- DOCME
-- @param object
-- @param what
-- @param ...
-- @return X
-- @see SendComponentQueryTo, SendEventTo
function M.SendMessageTo (object, what, ...)
    local redirect = Redirects[object]

    if redirect then
        object = redirect(object)
    end

    return Entity.SendMessage(object, what, ...)
end

return M