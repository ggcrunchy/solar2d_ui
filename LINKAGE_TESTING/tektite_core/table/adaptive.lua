--- Functionality for containers which may adapt among three forms:
--
-- <ul>
-- <li> **nil**. (0 elements)</li>
-- <li> A non-table value. (1 element)</li>
-- <li> A table of arbitrary values. (0 or more elements)</li>
-- </ul>
--
-- Containers are assumed to be either an array or set (potential or actual), but not both.
-- These fall under the types **AdaptiveArray** and **AdaptiveSet**, respectively.
--
-- The operations in the module are intended to smooth away these details, allowing callers
-- to pretend the container in question is in table form.

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
local ipairs = ipairs
local next = next
local pairs = pairs
local rawequal = rawequal
local remove = table.remove
local type = type

-- Cached module references --
local _AddToSet_
local _Append_
local _IterArray_
local _IterSet_
local _RemoveFromArray_
local _RemoveFromSet_
local _SimplifyArray_
local _SimplifySet_

-- Exports --
local M = {}

--
--
--

--- Adds an element to an adaptive set.
-- @tparam AdaptiveSet set
-- @param v Value to add; **nil** is ignored.
function M.AddToSet (set, v)
	if v ~= nil then
		-- If the container is a singleton, turn it into a one-element set. If the container
		-- is now in table form, add the new element. Since tables as values are ambiguous,
		-- they also go through this path; in this case, if no container yet exists, an empty
		-- set is created.
		if set ~= nil or type(v) == "table" then
			if type(set) ~= "table" then
				set = set ~= nil and { [set] = true } or {}
			end

			set[v] = true

		-- First element added: singleton container.
		else
			return v
		end
	end

	return set
end

--- Variant of @{AddToSet}, with `set = t[k]`.
--
-- The updated set is stored in _t_&#91;_k_&#93;.
-- @ptable t Table to update.
-- @param k Member key.
-- @param v Value to add; **nil** is ignored.
function M.AddToSet_Member (t, k, v)
	t[k] = _AddToSet_(t[k], v)
end

--- Appends an element to an adaptive array.
-- @tparam AdaptiveArray arr
-- @param v Value to append; **nil** is ignored.
-- @treturn AdapativeArray Updated array.
function M.Append (arr, v)
	-- If the container is a singleton, turn it into a one-element array. If the container
	-- is now in table form, append the new element. Since tables as values are ambiguous,
	-- they also go through this path; in this case, if no container yet exists, an empty
	-- array is created.
	if arr ~= nil or type(v) == "table" then
		if type(arr) ~= "table" then
			arr = { arr }
		end

		arr[#arr + 1] = v

		return arr

	-- First element added: singleton container.
	else
		return v
	end
end

--- Variant of @{Append}, with `arr = t[k]`.
--
-- The updated array is stored in _t_&#91;_k_&#93;.
-- @ptable t Target table.
-- @param k Member key.
-- @param v Value to append; **nil** is ignored.
function M.Append_Member (t, k, v)
	t[k] = _Append_(t[k], v)
end

--- Make a shallow copy of an adaptive array.
-- @tparam AdaptiveArray arr
-- @treturn AdaptiveArray Copy.
function M.CopyArray (arr)
	local out

	for _, v in _IterArray_(arr) do
		out = _Append_(out, v)
	end

	return out
end

--- Make a shallow copy of an adaptive set.
-- @tparam AdaptiveSet set
-- @treturn AdaptiveSet Copy.
function M.CopySet (set)
	local out

	for _, v in _IterSet_(set) do
		out = _AddToSet_(out, v)
	end

	return out
end

--- Predicate.
-- @tparam AdaptiveSet set Set to search.
-- @param v Value to find.
-- @treturn boolean _v_ is in _set_?
function M.InSet (set, v)
	if type(set) == "table" then
		return set[v] ~= nil
	else
		return v ~= nil and rawequal(set, v)
	end
end

local function Single_Array (arr, i)
	if i == 0 then
		return 1, arr, true
	end
end

--- Iterates over the (0 or more) elements in the array.
-- @tparam AdaptiveArray arr Array to iterate.
-- @treturn iterator Supplies index, value. If the value is a singleton, **true** is also
-- supplied as a third result.
function M.IterArray (arr)
	if type(arr) == "table" then
		return ipairs(arr)
	else -- nil or singleton
		return Single_Array, arr, arr ~= nil and 0
	end
end

local function Single_Set (set, guard)
	if set ~= guard then
		return set, false
	end
end

--- Iterates over the (0 or more) elements in the set.
-- @tparam AdaptiveSet set Set to iterate.
-- @treturn iterator Supplies value, boolean (if **true**, the set is in table form;
-- otherwise, the value is a singleton).
function M.IterSet (set)
	if type(set) == "table" then
		return pairs(set)
	else -- nil or singleton
		return Single_Set, set
	end
end

-- Tries to remove a value from the adaptive container, accounting for non-tables
local function AuxRemove (func, cont, v)
	if type(cont) == "table" then
		func(cont, v)
	elseif rawequal(cont, v) then
		cont = nil
	end

	return cont
end

local function ArrayRemove (arr, v)
	for i, elem in ipairs(arr) do
		if rawequal(elem, v) then
			remove(arr, i)

			break
		end
	end
end

--- Removes an element from an adaptive array.
--
-- If _arr_ is **nil** or _v_ is absent, this is a no-op.
-- @tparam AdaptiveArray arr
-- @param v Value to remove.
-- @treturn AdaptiveArray Updated array.
function M.RemoveFromArray (arr, v)
	return AuxRemove(ArrayRemove, arr, v)
end

--- Variant of @{RemoveFromArray}, with `arr = t[k]`.
--
-- If _arr_ is **nil** or _v_ is absent, this is a no-op.
--
-- The updated array is stored in _t_&#91;_k_&#93;.
-- @ptable t Table to update.
-- @param k Member key.
-- @param v Value to remove.
function M.RemoveFromArray_Member (t, k, v)
	t[k] = _RemoveFromArray_(t[k], v)
end

local function SetRemove (set, v)
	if v ~= nil then
		set[v] = nil
	end
end

--- Removes an element from an adaptive set.
--
-- If _set_ is **nil** or _v_ is absent, this is a no-op.
-- @tparam AdaptiveSet set
-- @param v Value to remove.
-- @treturn AdaptiveSet Updated set.
function M.RemoveFromSet (set, v)
	return AuxRemove(SetRemove, set, v)
end

--- Variant of @{RemoveFromSet}, with `set = t[k]`.
--
-- If _set_ is **nil** or _v_ is absent, this is a no-op.
--
-- The updated set is stored in _t_&#91;_k_&#93;.
-- @ptable t Table to update.
-- @param k Member key.
-- @param v Value to remove.
function M.RemoveFromSet_Member (t, k, v)
	t[k] = _RemoveFromSet_(t[k], v)
end

local function AuxSimplify (t, first, second)
	if first == nil then
		return nil
	elseif second == nil and type(first) ~= "table" then
		return first
	end

	return t
end

--- If _arr_ is not a table, this is a no-op.
--
-- Otherwise, it decays back to a singleton or **nil**, if possible.
-- @tparam AdaptiveArray arr
-- @treturn AdaptiveArray Updated array.
function M.SimplifyArray (arr)
	if type(arr) == "table" then
		return AuxSimplify(arr, arr[1], arr[2])
	end

	return arr
end

--- Variant of @{SimplifyArray}, with `arr = t[k]`.
--
-- The updated array is stored in _t_&#91;_k_&#93;.
-- @ptable t Table to update.
-- @param k Member key.
function M.SimplifyArray_Member (t, k)
	t[k] = _SimplifyArray_(t[k])
end

--- If _set_ is not a table, this is a no-op.
--
-- Otherwise, it decays back to a singleton or **nil**, if possible.
-- @param set Adaptive set to simplify.
-- @treturn AdaptiveSet Updated set.
function M.SimplifySet (set)
	if type(set) == "table" then
		local first = next(set)

		return AuxSimplify(set, first, next(set, first))
	end

	return set
end

--- Variant of @{SimplifySet}, with `set = t[k]`.
--
-- The updated set is stored in _t_&#91;_k_&#93;.
-- @ptable t Table to update.
-- @param k Member key.
function M.SimplifySet_Member (t, k)
	t[k] = _SimplifySet_(t[k])
end

_AddToSet_ = M.AddToSet
_Append_ = M.Append
_IterArray_ = M.IterArray
_IterSet_ = M.IterSet
_RemoveFromArray_ = M.RemoveFromArray
_RemoveFromSet_ = M.RemoveFromSet
_SimplifyArray_ = M.SimplifyArray
_SimplifySet_ = M.SimplifySet

return M