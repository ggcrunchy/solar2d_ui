--- Collections of links between objects.
--
-- A link is formed between two endpoints: `(id1, name1)` and `(id2, name2)`. The (distinct)
-- IDs specify the objects themselves, whereas the names denote particular attachment
-- points. An example pairing: `(7, "out")-(2, "in")`.
--
-- An object may be linked to multiple objects, or even to the same object multiple times via
-- different attachment points.
--
-- An **ID** or **Name** may be any value other than **nil** or NaN.
-- @module LinkCollection

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
local next = next
local pairs = pairs
local rawequal = rawequal
local setmetatable = setmetatable
local type = type

-- Exports --
local M = {}

--
--
--

local Link = {}

Link.__index = Link

local function LinkPosition (owner, link)
	local n = #owner

	for i = 1, n do
		if owner[i] == link then
			return i, n
		end
	end
end

--- If this link is intact, break it.
-- @see Link:IsIntact
function Link:Break ()
	local pair_links = self.m_owner

	if pair_links then
		local i, n = LinkPosition(pair_links, self)

		assert(i, "Link not found in list")

		pair_links[i] = pair_links[n]
		pair_links[n] = nil

		self.m_owner = nil -- n.b. list might now be empty but keep around
	end
end

---
-- @treturn[1] ID ID #1...
-- @treturn[1] Name ...and name of corresponding attachment point.
-- @treturn[1] ID ID #2...
-- @treturn[1] Name ...ditto.
-- @return[2] **nil**, meaning the link is no longer intact.
-- @see Link:GetOtherPair, Link:IsIntact
function Link:GetLinkedPairs ()
	local pair_links = self.m_owner

	if pair_links then
		return pair_links.id1, self.m_name1, pair_links.id2, self.m_name2
	end

	return nil
end

---
-- @tparam id
-- @treturn[1] Name
-- @return[1] **nil**, meaning neither pair uses _id_ or the link is no longer intact.
function Link:GetName (id)
	local pair_links = self.m_owner

	if pair_links then
		if rawequal(id, pair_links.id1) then
			return self.m_name1
		elseif rawequal(id, pair_links.id2) then
			return self.m_name2
		end
	end

	return nil
end

---
-- @tparam ID id
-- @treturn[1] ID The ID paired with _id_ in this link...
-- @treturn[1] Name ...and the name of its attachment point.
-- @return[2] **nil**, meaning neither pair uses _id_ or the link is no longer intact.
-- @see LinkCollection:LinkPairs, Link:GetLinkedPairs, Link:IsIntact
function Link:GetOtherPair (id)
	local pair_links = self.m_owner

	if pair_links then
		local id1, id2 = pair_links.id1, pair_links.id2

		if rawequal(id, id1) then
			return id2, self.m_name2
		elseif rawequal(id, id2) then
			return id1, self.m_name1
		end
	end

	return nil
end

---
-- @treturn boolean The link is still intact?
-- @see LinkCollection:LinkPairs, LinkCollection:Remove, Link:Break
function Link:IsIntact ()
	return self.m_owner ~= nil
end

local LinkCollection = {}

LinkCollection.__index = LinkCollection

local Counter, IDToCounter = 0

local function GetCounter (id)
	if id == "__mode" then -- guard for weak table key
		return -1
	elseif not IDToCounter then
		IDToCounter = { __mode = "k" }

		setmetatable(IDToCounter, IDToCounter)
	end

	local counter = IDToCounter[id]

	if not counter then
		counter = Counter
		Counter, IDToCounter[id] = Counter + 1, counter
	end

	return counter
end

local function LessThan (id1, id2)
	local type1, type2 = type(id1), type(id2)

	if type1 ~= type2 then
		return type1 < type2
	elseif type1 == "string" or type1 == "number" then
		return id1 < id2
	elseif type1 == "boolean" then
		return id1 -- n.b. will be keys, so one must be true and the other false
	else -- GC object
		return GetCounter(id1) < GetCounter(id2)
	end
end

local function NameKey (id1, id2)
	return LessThan(id1, id2) and "m_name1" or "m_name2"
end

---
-- @tparam ID id
-- @tparam Name name
-- @treturn uint Number of links to _id_ via _name_.
function LinkCollection:CountLinks (id, name)
	local list, count = self[id], 0

	if list then
		for id2, pair_links in pairs(list) do
			local key = NameKey(id, id2)

			for _, link in ipairs(pair_links) do
				if rawequal(link[key], name) then
					count = count + 1
				end
			end
		end
	end

	return count
end

--- DOCME
-- @callable func
-- @param arg
function LinkCollection:ForEachLink (func, arg)
	for id1, list in pairs(self) do
		for id2, pair_links in pairs(list) do
			if LessThan(id1, id2) then -- first time seeing pair?
				for _, link in ipairs(pair_links) do
					func(link, arg)
				end
			end
		end
	end
end

--- DOCME
-- @tparam ID id
-- @callable func
-- @param arg
function LinkCollection:ForEachLinkWithID (id, func, arg)
	local list = self[id]

	if list then
		for _, pair_links in pairs(list) do
			for _, link in ipairs(pair_links) do
				func(link, id, arg)
			end
		end
	end
end

--- DOCME
-- @tparam ID id
-- @param name
-- @callable func
-- @param arg
function LinkCollection:ForEachPairLink (id, name, func, arg)
	local list = self[id]

	if list then
		for id2, pair_links in pairs(list) do
			local key = NameKey(id, id2)

			for _, link in ipairs(pair_links) do
				if rawequal(link[key], name) then
					func(link, id, arg)
				end
			end
		end
	end
end

---
-- @tparam ID id
-- @treturn boolean X
function LinkCollection:HasAnyLinks (id)
	local list = self[id]

	if list then
		for _, pair_links in pairs(list) do
			if #pair_links > 0 then
				return true
			end
		end
	end

	return false
end

---
-- @tparam ID id
-- @tparam Name name
-- @treturn boolean X
function LinkCollection:HasLinks (id, name)
	local list = self[id]

	if list then
		for id2, pair_links in pairs(list) do
			local key = NameKey(id, id2)

			for _, link in ipairs(pair_links) do
				if rawequal(link[key], name) then
					return true
				end
			end
		end
	end

	return false
end

local function AuxIterIDs (LC, prev)
	return (next(LC, prev))
end

---
-- @return Iterator that supplies each **ID** involved in links.
-- @see LinkCollection:LinkPairs, LinkCollection:Remove
function LinkCollection:IterIDs ()
	return AuxIterIDs, self, nil
end

local function FindLink (pair_links, name1, name2)
	for _, link in ipairs(pair_links) do
		if rawequal(link.m_name1, name1) and rawequal(link.m_name2, name2) then
			return link
		end
	end
end

local function GetList (LC, id)
	local list = LC[id] or {}

	LC[id] = list

	return list
end

local function CheckValue (v, what)
	assert(v ~= nil and v == v, what)
end

--- DOCME
-- @tparam ID id1
-- @tparam Name name1
-- @tparam ID id2
-- @tparam Name name2
-- @treturn[1] Link L
-- @return[2] **nil**, indicating failure.
-- @treturn[2] string Reason for failure.
function LinkCollection:LinkPairs (id1, name1, id2, name2)
	CheckValue(id1, "Invalid ID #1")
	CheckValue(id2, "Invalid ID #2")
	CheckValue(name1, "Invalid name #1") -- strictly speaking, nil names are allowed, but these
	CheckValue(name2, "Invalid name #2") -- might introduce confusion with genuine errors

	if rawequal(id1, id2) then
		return nil, "Equal IDs"
	elseif LessThan(id2, id1) then -- impose an arbitrary but consistent order for later lookup
		id1, name1, id2, name2 = id2, name2, id1, name1
	end

	local list1, list2 = GetList(self, id1), GetList(self, id2)
	local pair_links = list1[id2]

	assert(pair_links == list2[id1], "Mismatched pair links") -- same table or both nil

	if pair_links then
		assert(rawequal(pair_links.id1, id1), "Mismatch with pair ID #1")
		assert(rawequal(pair_links.id2, id2), "Mismatch with pair ID #2")

		if FindLink(pair_links, name1, name2) then
			return nil, "IDs already linked via these attachment points"
		end
	else
		pair_links = { id1 = id1, id2 = id2 }
		list1[id2], list2[id1] = pair_links, pair_links
	end

	local link = setmetatable({ m_owner = pair_links, m_name1 = name1, m_name2 = name2 }, Link)

	pair_links[#pair_links + 1] = link

	return link
end

--- DOCME
-- @tparam ID id
-- @see Link:IsIntact
function LinkCollection:Remove (id)
	local list = self[id]

	if list then
		for id2, pair_links in pairs(list) do
			for _, link in ipairs(pair_links) do
				link.m_owner = nil -- links might still be referenced, so invalidate them
			end

			self[id2][id] = nil -- throw away paired IDs' references to link arrays...
		end

		self[id] = nil -- ...along with those from the removed ID
	end
end

--- DOCME
-- @treturn LinkCollection
function M.New ()
	return setmetatable({}, LinkCollection)
end

return M