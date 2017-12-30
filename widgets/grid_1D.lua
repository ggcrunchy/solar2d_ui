--- 1D grid UI elements.
--
-- @todo Document skin...

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
local abs = math.abs
local ipairs = ipairs
local min = math.min
local type = type

-- Modules --
local array_index = require("tektite_core.array.index")
local button = require("corona_ui.widgets.button")
local colors = require("corona_ui.utils.color")
local layout = require("corona_ui.utils.layout")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local sheet = require("corona_utils.sheet")
local skins = require("corona_ui.utils.skin")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local native = native
local system = system
local transition = transition

-- Imports --
local GetColor = colors.GetColor

-- Exports --
local M = {}

--
local BarTouch = touch.DragParentTouch{ ref_key = "m_backdrop" }

--
local function AddOptionGridLine (group, skin, x1, y1, x2, y2)
	local line = display.newLine(group, x1, y1, x2, y2)

	line.strokeWidth = skin.optiongrid_linewidth

	line:setStrokeColor(GetColor(skin.optiongrid_linecolor))

	return line
end

--
local function CancelTransitions (tlist)
	for i = #tlist, 1, -1 do
		transition.cancel(tlist[i])

		tlist[i] = nil
	end
end

--
local function X (i, dw)
	return (i - 2) * dw
end

-- Roll transition --
local RollParams = { time = 550, transition = easing.inOutExpo }

-- --
local ScaleTo = { 1, .75, .5, .75 }

--
local function SetScale (object, index)
	local scale = ScaleTo[abs(index - 2) + 1]

	object.xScale = scale
	object.yScale = scale
end

-- --
local InterpParams = {}

--
local function SetFrame (object, frame)
	if not object.m_is_image then
		sheet.SetSpriteSetImageFrame(object, frame)
	end
end

--
local function Roll (transitions, parts, oindex, dw, advance)
	local other, with_trans, add = parts[4], type(transitions) == "table", 0

	if with_trans then
		other.m_to_left = dw < 0
	else
		other.x, advance = X(dw < 0 and 4 or 0, abs(dw)), true

		SetFrame(other, oindex)
	end

	if advance then
		add = dw < 0 and -1 or 1
	end

	local params = with_trans and RollParams or InterpParams
	local t = params == InterpParams and transitions

	for i, part in ipairs(parts) do
		SetScale(params, i + add)

		params.x = part.x + dw

		if t then
			local s = 1 - t

			part.x = s * part.x + t * InterpParams.x
			part.xScale = s * part.xScale + t * InterpParams.xScale
			part.yScale = s * part.yScale + t * InterpParams.yScale
		else
			params.onComplete = part == other and transitions.onComplete or nil

			transitions[i] = transition.to(part, RollParams)
		end
	end
end

--- d
-- @pgroup group
-- @number x
-- @number y
-- @number w
-- @number h
-- @string text
-- @ptable opts[opt]
-- @treturn DisplayGroup X
function M.OptionsHGrid (group, x, y, w, h, text, opts)
	local skin = skins.GetSkin(opts and opts.skin)

	--
	local ggroup, tformat = display.newGroup()

	if opts and opts.types then
		tformat, text = { form = text }, ""

		for _, str in ipairs(opts.types) do
			tformat[#tformat + 1] = str
		end
	end

	--
	w, h = layout_dsl.EvalDims(w, h)

	local dw, dh = w / 3, h / 2
	local cx, cy = w / 2, 1.5 * dh
	local backdrop = display.newRect(ggroup, cx, dh, w, h)
	local bar = display.newRect(ggroup, cx, dh / 2, w, dh)
	local choice = display.newRect(ggroup, cx, cy, dw, dh - 2)
	local string = display.newText(ggroup, text or "", bar.x, bar.y, skin.optiongrid_font, layout.ResolveY(skin.optiongrid_textsize))

	bar.m_backdrop = backdrop

	bar.strokeWidth = skin.optiongrid_barborderwidth
	backdrop.strokeWidth = skin.optiongrid_backdropborderwidth

	bar:setFillColor(GetColor(skin.optiongrid_barcolor))
	bar:setStrokeColor(GetColor(skin.optiongrid_barbordercolor))
	backdrop:setFillColor(GetColor(skin.optiongrid_backdropcolor))
	backdrop:setStrokeColor(GetColor(skin.optiongrid_backdropbordercolor))
	choice:setFillColor(GetColor(skin.optiongrid_choicecolor))
	string:setFillColor(GetColor(skin.optiongrid_textcolor))

	-- 
	bar:addEventListener("touch", BarTouch)

	--
	local x2, y2 = dw * 2, dh * 2 - 1
	local lline = AddOptionGridLine(ggroup, skin, dw, dh + 1, dw, y2)
	local rline = AddOptionGridLine(ggroup, skin, x2, dh + 1, x2, y2)

	--
	local sprite_count, sprite_index

	local function Rotate (to_left, i)
		return array_index.RotateIndex(i or sprite_index, sprite_count, to_left)
	end

	--
	local function SetIndex (index)
		if tformat then
			string.text = tformat.form:format(tformat[index])
		end

		sprite_index = index
	end

	--
	local parts, trans = {}, {}

	function trans.onComplete (other)
		--
		for i = #trans, 1, -1 do
			trans[i] = nil
		end

		--
		if other.m_to_left then
			parts[4], parts[1], parts[2], parts[3] = parts[1], parts[2], parts[3], parts[4]
		else
			parts[1], parts[2], parts[3], parts[4] = parts[4], parts[1], parts[2], parts[3]
		end
	end

	backdrop:addEventListener("touch", touch.TouchHelperFunc(function(event, target)
		target.m_current = target.parent:GetCurrent()
		target.m_x = target:contentToLocal(event.x, 0)
	end, function(event, target)
		local x = target:contentToLocal(event.x, 0)
		local diff = x - target.m_x

		if target.m_moved or abs(diff) > 4 then
			local current, adiff, to_left = target.m_current, abs(diff), diff < 0

			while adiff >= dw do
				current, adiff = Rotate(to_left, current), adiff - dw
			end

			target.parent:SetCurrent(current)

			local oindex = current

			for _ = 1, 2 do
				oindex = Rotate(to_left, oindex)
			end

			Roll(adiff / dw, parts, oindex, to_left and dw or -dw)

			target.m_moved = true
		end
	end, function(event, target)
		if target.m_moved and sprite_index and #trans == 0 then
			local diff = target:contentToLocal(event.x, 0) - target.m_x
			local adiff, to_left = abs(diff) % dw, diff > 0
			local delta, advance = adiff

			if adiff > dw / 2 then
				to_left, delta, advance = not to_left, dw - adiff, true

				SetIndex(Rotate(to_left))
			end

			if delta > 0 then
				Roll(trans, parts, Rotate(to_left), to_left and delta or -delta, advance)
			end
		end

		target.m_moved = nil
	end))

	--
	local pgroup = display.newContainer(w, dh)

	ggroup:insert(pgroup)
	pgroup:translate(cx, cy)

	--
	layout_dsl.PutObjectAt(ggroup, x, y)

	group:insert(ggroup)

	--- DOCME
	-- @param images
	-- @int count
	-- @int index
	function ggroup:Bind (images, count, index)
		--
		for i = #parts, 1, -1 do
			parts[i]:removeSelf()

			parts[i] = nil
		end

		--
		if images and count > 0 then
			local is_single_image = type(images) == "string"

			for i = 1, 4 do
				if is_single_image then
					parts[i] = display.newImageRect(pgroup, images, dw, dh)

					parts[i].m_is_image = is_single_image
				else
					parts[i] = sheet.NewImage(pgroup, images, 0, 0, dw, dh)
				end
			end

			--
			sprite_count = count

			self:SetCurrent(index or 1)

			--
			lline:toFront()
			rline:toFront()

		--
		else
			CancelTransitions(trans)

			sprite_index = nil

			if tformat then
				string.text = ""
			end
		end
	end

	--- DOCME
	-- @treturn uint X
	function ggroup:GetCurrent ()
		return sprite_index
	end

	--- DOCME
	-- @uint current
	function ggroup:SetCurrent (current)
		CancelTransitions(trans)
		SetIndex(current)

		if #parts > 0 then
			SetFrame(parts[1], Rotate(true))
			SetFrame(parts[2], sprite_index)
			SetFrame(parts[3], Rotate(false))

			for i, part in ipairs(parts) do
				part.x = X(i, dw)

				SetScale(part, i)
			end
		end
	end

	--
	return ggroup
end

-- Main option grid skin --
skins.AddToDefaultSkin("optiongrid", {
	barcolor = { type = "gradient", color1 = { 0, 0, .25 }, color2 = { 0, 0, 1 }, direction = "down" },
	barbordercolor = "red",
	barborderwidth = 2,
	backdropcolor = { type = "gradient", color1 = { 0, .25, 0 }, color2 = { 0, 1, 0 }, direction = "up" },
	backdropbordercolor = { type = "gradient", color1 = { .25, 0, 0 }, color2 = { 1, 0, 0 }, direction = "up" },
	backdropborderwidth = 2,
	choicecolor = "red",
	font = native.systemFont,
	linecolor = "blue",
	linewidth = 2,
	textcolor = "white",
	textsize = "3%",
	scrollsep = 0
})

-- Export the module.
return M