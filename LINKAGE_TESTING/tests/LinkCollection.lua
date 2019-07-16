--- Links and tags unit test. (TODO: this was written for a rather older version and "tags" have been decoupled, largely into NodePattern)

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
local button = require("ui.Button")
local scenes = require("utils.Scenes")

-- Classes --
local LinksClass = require("tektite_base_classes.Link.Links")
local TagsClass = require("tektite_base_classes.Link.Tags")

-- Corona modules --
local composer = require("composer")

-- Test scene --
local Scene = composer.newScene()

--
function Scene:create ()
	button.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Title" }, "Go Back")
end

Scene:addEventListener("create")

--
function Scene:show (event)
	if event.phase == "will" then
		return
	end

	local TagsInstance = TagsClass()
	local LinksInstance = LinksClass(TagsInstance, function(object)
		return object.parent
	end)

	local Objs = {}

	local function C (name, tag)
		local c = display.newCircle(self.view, 0, 0, 5)

		c.isVisible = false

		c.m_name = name

		LinksInstance:SetTag(c, tag)

		Objs[#Objs + 1] = c
	end

	local function print1 (...)
		print("  ", ...)
	end

	local function print2 (...)
		print("  ", "  ", ...)
	end

	LinksInstance:SetRemoveFunc(function(object)
		print1("Goodbye, " .. object.m_name)
	end)

	-- Define tag: so far so good
	TagsInstance:New("MIRBLE", { sub_links = { Burp = true, Slerp = true, Derp = true } })
	TagsInstance:New("ANIMAL")
	TagsInstance:New("DOG", { "ANIMAL" })
	TagsInstance:New("CAT", { "ANIMAL", "MIRBLE" })
	TagsInstance:New("WOB", { "CAT" })

	-- Create and Set tags: so far so good
	C("j", "MIRBLE")
	C("k", "ANIMAL")
	C("l", "DOG")
	C("m", "CAT")
	C("n", "WOB")

	for _, v in ipairs(Objs) do
		local tag = LinksInstance:GetTag(v) -- Get tag: good

		print("object:", v.m_name)
		print("tag:", tag)

		local function P (tt)
			if type(tt) ~= "string" then
				print2(tt.m_name)
			elseif tt ~= tag then
				print2(tt)
			end
		end

		-- Children: good
		print1("CHILDREN!")

		for _, tt in TagsInstance:TagAndChildren(tag) do
			P(tt)
		end

		-- Multi-children: good
		print1("MULTI-CHILDREN (tag + ANIMAL)")

		for _, tt in TagsInstance:TagAndChildren--[[_Multi]]({ tag, "ANIMAL" }) do
			P(tt)
		end

		-- Parents: good
		print1("PARENTS!")

		for _, tt in TagsInstance:TagAndParents(tag) do
			P(tt)
		end

		-- Multi-parents: good
		print1("MULTI-PARENTS (tag + WOB)")

		for _, tt in TagsInstance:TagAndParents--[[_Multi]]({ tag, "WOB" }) do
			P(tt)
		end

		print("")

		-- Sublinks: good
		print1("Sublinks")

		for _, tt in TagsInstance:Sublinks(tag) do
			P(tt)
		end

		-- Has child: good
		print1("Has child: WOB", TagsInstance:HasChild(tag, "WOB"))
		print1("Has child: DOG", TagsInstance:HasChild(tag, "DOG"))
		print1("Has child: MOOP", TagsInstance:HasChild(tag, "MOOP"))

		-- Is: good
		print1("Is: MIRBLE", TagsInstance:Is(tag, "MIRBLE"))
		print1("Is: WOB", TagsInstance:Is(tag, "WOB"))
		print1("Is: GOOM", TagsInstance:Is(tag, "GOOM"))

		-- Has sublink: good
		print1("Has sublink: Derp", TagsInstance:HasSublink(tag, "Derp"))
		print1("Has sublink: nil", TagsInstance:HasSublink(tag, nil))
		print1("Has sublink: OOMP", TagsInstance:HasSublink(tag, "OOMP"))

		-- Tagged: good
		print1("Tagged")

		for _, tname in TagsInstance:TagAndChildren(tag) do
			for tt in LinksInstance:Tagged(tname) do
				P(tt)
			end
		end
	end

	local Messages = {}

	local function Print (message)
		if not Messages[message] then
			print1(message)

			Messages[message] = true
		end
	end

	-- Create links with can_link, sub_links
	local SubLinks = {}

	local From = #Objs

	for i = 1, 20 do
		local sub_links = {}

		for j = 1, i % 3 do
			sub_links[j] = "SL_" .. ((i + 2) % 5)
		end

		local can_link = true

		if i > 5 then
			function can_link (o1, o2, sub1, sub2)
				local num, message = (sub2 and sub2:GetName() or ""):match("SL_(%d+)") or 0 / 0

				if i <= 10 then
					message = num % 2 == 0 and "5 to 10, link to evens"
				elseif i <= 15 then
					message = num % 2 == 1 and "11 to 15, link to odds"
				else
					message = (sub2 == nil or num % 3 == 0) and "16 to 20, link to 3 * n / nil"
				end

				if message and Print then
					Print(message .. ": (" .. tostring(sub1:GetName()) .. ", " ..tostring(sub2:GetName()) .. ")")
				end

				return not not message
			end
		end

		local links = {}

		for _, v in ipairs(sub_links) do
			links[v] = can_link
		end

		SubLinks[i] = sub_links

		TagsInstance:New("tag_" .. i, { sub_links = links })

		C("object_" .. i, "tag_" .. i)
	end

	-- Can link: good?
	print("What can link?")

	local Links = {}

	for i = 1, 20 do
		for j = 1, 20 do
			if i ~= j then
				local o1, o2 = Objs[From + i], Objs[From + j]

				for k = 1, #SubLinks[i] + 1 do
					for l = 1, #SubLinks[j] + 1 do
						local sub1, sub2 = SubLinks[i][k], SubLinks[j][l]

						if LinksInstance:CanLink(o1, o2, sub1, sub2) then
							Links[#Links + 1] = { From + i, From + j, link = LinksInstance:LinkObjects(o1, o2, sub1, sub2) }

							assert(Links[#Links].link, "Invalid link")
						end
					end
				end
			end
		end
	end

	Print = nil

	print("Number of links: ", #Links)
	print("Let's break some!")

	local function LinkIndex (i)
		return i % #Links + 1
	end

	for _, v in ipairs{ 100, 200, 300, 400, 500, 600 } do
		local i = LinkIndex(v)
		local intact, o1, o2, sub1, sub2 = Links[i].link:GetObjects()

		print1("Link " .. i .. " intact?", intact, o1 and o1.m_name, o2 and o2.m_name, sub1, sub2)

		Links[i].link:Break()
	end

	print("State of one of those...")

	print1("Link ", LinkIndex(200), Links[LinkIndex(200)].link:GetObjects())

	print("Let's destroy some objects!")

	for _, v in ipairs{ 50, 150, 250, 350, 450 } do
		local i = LinkIndex(v)
		local intact, o1, o2 = Links[i].link:GetObjects()

		if intact then
			local which

			if i % 2 == 0 then
				print("Link " .. i .. ", breaking object 1")

				which = o1
			else
				print("Link " .. i .. ", breaking object 2")

				which = o2
			end

			print1("Intact before?", Links[i].link:IsIntact())

			which:removeSelf()

			print1("Intact after?", Links[i].link:IsIntact())
		end
	end

	-- Links...
	local index = LinkIndex(173)
	local link = Links[index].link
	local intact, lo, _, s1 = link:GetObjects()

	local function Obj (obj, sub, self)
		if obj == self then
			return "SELF"
		else
			return obj.m_name .. " (" .. tostring(sub) .. ")"
		end
	end

	print("Links belonging to link " .. index .. ", SELF = " .. Obj(lo, s1))

	for li in LinksInstance:Links(lo, s1) do
		local _, obj1, obj2, sub1, sub2 = li:GetObjects()

		print1("LINK: ", Obj(obj1, sub1, lo) .. " <-> " .. Obj(obj2, sub2, lo))
	end

	for i = -1, 7 do
		local sub = i ~= -1 and "SL_" .. i or nil

		print("Has links (" .. tostring(sub) .. ")?", LinksInstance:HasLinks(lo, sub))
	end


end

Scene:addEventListener("show")

--
function Scene:hide ()
	-- ??
end

Scene:addEventListener("hide")

return Scene

--[[
Needs a home:

-- Listen to events.
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