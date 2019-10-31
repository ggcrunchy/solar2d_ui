--- Link collection unit test.

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

-- Modules --
local LC = require("s3_editor.LinkCollection")

--
--
--

local lc = LC.New()

--[[
Link:Break
Link:GetLinkedPairs
Link:GetName
Link:GetOtherPair
Link:IsIntact

LinkCollection:CountLinks
LinkCollection:ForEachLink
LinkCollection:ForEachLinkWithID
LinkCollection:ForEachPairLink
LinkCollection:HasLinks
LinkCollection:IterIDs
LinkCollection:LinkPairs
LinkCollection:Remove
]]

print("REMOVE NOTHING")

lc:Remove()
lc:Remove(37)

print("")

print("BOGUS LINK COUNT:", lc:CountLinks(36, "dog"))
print("")

print("BOGUS HAS LINKS:", lc:HasLinks(33, "koala"))
print("")

print("ENUM IDS SO FAR")

for id in lc:IterIDs() do
	print("ID", id)
end

print("")

print("ENUM IDS SO FAR")

for id in lc:IterIDs() do
	print("  ", id)
end

print("")

print("FOR EACH LINK SO FAR")

lc:ForEachLink(error)

print("")

print("FOR EACH LINK WITH ID SO FAR")

lc:ForEachLinkWithID(39, error)

print("")

print("FOR EACH PAIR LINK SO FAR")

lc:ForEachPairLink(31, "cat", error)

print("")

local link1 = lc:LinkPairs(27, "panda", 41, "monkey")

print("INTACT?", link1:IsIntact())
print("WHAT'S LINKED?", link1:GetLinkedPairs())
print("OTHER THAN", 27, link1:GetOtherPair(27))
print("OTHER THAN", 41, link1:GetOtherPair(41))
print("OTHER THAN", 332, link1:GetOtherPair(332))
print("")

print("ENUM IDS SO FAR")

for id in lc:IterIDs() do
	print("  ", id)
end

print("")

lc:LinkPairs(27, "panda", 67, "ox")
lc:LinkPairs(27, "weasel", 67, "ox")
lc:LinkPairs(27, "camel", 31, "duck")

print("TRY LINKING AGAIN", lc:LinkPairs(27, "panda", 67, "ox"))
print("panda?", lc:HasLinks(27, "panda"))
print("N", lc:CountLinks(27, "panda"))
print("weasel?", lc:HasLinks(27, "weasel"))
print("N", lc:CountLinks(27, "weasel"))
print("lizard?", lc:HasLinks(27, "lizard"))
print("N", lc:CountLinks(27, "lizard"))
print("ox?", lc:HasLinks(67, "ox"))
print("N", lc:CountLinks(67, "ox"))
print("")

print("ENUM IDS SO FAR")

for id in lc:IterIDs() do
	print("  ", id)
end

print("")

print("FOR EACH LINK WITH ID SO FAR")

lc:ForEachLinkWithID(27, function(link, id)
	print(id, link:GetName(id), "linked to", link:GetOtherPair(id))
end)

print("")

print("FOR EACH PAIR LINK SO FAR")

lc:ForEachPairLink(67, "ox", function(link, id)
	print(id, link:GetName(id), "linked to", link:GetOtherPair(id))
end)

print("")

print("BREAKING LINK", link1:GetLinkedPairs())

link1:Break()

print("INTACT?", link1:IsIntact())
print("WHAT'S LINKED?", link1:GetLinkedPairs())

print("")

print("ENUM IDS SO FAR")

for id in lc:IterIDs() do
	print("  ", id)
end

print("")

print("FOR EACH LINK WITH ID SO FAR")

lc:ForEachLinkWithID(27, function(link, id)
	print(id, link:GetName(id), "linked to", link:GetOtherPair(id))
end)

print("")

print("ADDING ANOTHER")

lc:LinkPairs(27, "bird", 39, "worm")

print("")

print("REMOVING")

lc:Remove(67)

print("")

print("ENUM IDS SO FAR")

for id in lc:IterIDs() do
	print("  ", id)
end

print("")

print("FOR EACH LINK WITH ID SO FAR")

lc:ForEachLinkWithID(27, function(link, id)
	print(id, link:GetName(id), "linked to", link:GetOtherPair(id))
end)

print("")

print("FOR EACH PAIR LINK SO FAR")

lc:ForEachPairLink(67, "ox", function(link, id)
	print(id, link:GetName(id), "linked to", link:GetOtherPair(id))
end)

print("")

-- TODO: now try with non-integer / string IDs and names...

--[[
Needs a home:

dispatch_list.AddToMultipleLists{
	-- Build Level --
	build_level = function(level)
		-- ??
		-- Iterate list of links, dispatch out to objects? (some way to look up values from keys...)
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		-- ??
		-- SetArray() -> lookup tag, key combos?
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		-- ??
		-- GetArray() -> save tag, key combos?
	end,

	-- Verify Level --
	verify_level = function(verify)
		-- ??
		-- Iterate list of links and ask objects?
	end
}
]]