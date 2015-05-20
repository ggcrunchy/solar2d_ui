--- Keyboard widget for non-native off-device input.
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
local ipairs = ipairs
local lower = string.lower
local max = math.max
local tonumber = tonumber
local upper = string.upper

-- Imports --
local button = require("corona_ui.widgets.button")
local colors = require("corona_ui.utils.color")
local layout = require("corona_ui.utils.layout")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local skins = require("corona_ui.utils.skin")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local Runtime = Runtime

-- Cached module references --
local _Keyboard_XY_

-- Exports --
local M = {}

-- --
local KeyEvent = {
	name = "key", descriptor = "Emulated key",
	nativeKeyCode = -1,
	isAltDown = false, isCommandDown = false, isCtrlDown = false
}

--
local function SendKeyEvent (name, is_shift_down)
	KeyEvent.keyName = name
	KeyEvent.isShiftDown = not not is_shift_down

	KeyEvent.phase = "down"

	Runtime:dispatchEvent(KeyEvent)

	KeyEvent.phase = "up"

	Runtime:dispatchEvent(KeyEvent)
end

--
local function AddText (button)
	local kgroup, btext = button.parent, button:GetText()

	--
	if btext == "A>a" or btext == "a>A" then
		local func = btext == "A>a" and lower or upper

		for i = 2, kgroup.numChildren do
			local ctext = kgroup[i]:GetText()

			if #ctext == 1 then
				kgroup[i]:SetText(func(ctext))
			end
		end

		button:SetText(func == lower and "a>A" or "A>a")

	--
	elseif btext == "<-" then
		SendKeyEvent("deleteBack")

	--
	elseif btext ~= "OK" then
		if btext == " " then
			SendKeyEvent("space")
		elseif btext == "_" then
			SendKeyEvent("-", true)
		else
			local lc = lower(btext)

			if #btext == 1 and lc ~= upper(btext) then
				SendKeyEvent(lc, btext ~= lc)
			else
				SendKeyEvent(btext)
			end
		end

	--
	else
		SendKeyEvent("enter")
	end
end

-- --
local Chars = {
	"QWERTYUIOP",
	"@1ASDFGHJKL",
	"@2ZXCVBNM@S",
	"@5 _"
}

-- --
local Nums = {
	"789",
	"456",
	"123",
	"0."
}

-- --
local Other = {
	"@B",
	"", "",
	"@X"
}

-- --
local Scales = { OK = 2, ["<-"] = 2, [" "] = 7, ["0"] = 2, ["A>a"] = 2 }

-- --
local Subs = { B = "<-", S = "A>a", X = "OK" }

--
local function ProcessRow (group, skin, row, x, y, w, h, xsep)
	local opts, prev = { skin = skin }

	for char in row:gmatch(".") do
		local skip, text = char == "@"

		if prev ~= "@" then
			text = char
		elseif tonumber(char) then
			x, skip = x + char * w / 2, true
		else
			text = Subs[char]
		end

		prev, opts.text = char, text

		--
		if not skip then
			local dim = (Scales[text] or 1) * w
			local button = button.Button_XY(group, x, y, dim, h, AddText, opts)

			button:translate(button.width / 2, button.height / 2)

			x = x + xsep + dim
		end
	end

	return x
end

--
local function DoRows (group, skin, rows, x, y, w, h, xsep, ysep)
	local rw = -1

	for _, row in ipairs(rows) do
		rw, y = max(rw, ProcessRow(group, skin, row, x, y, w, h, xsep)), y + ysep + h
	end

	return rw, y
end

--
local BackTouch = touch.DragParentTouch()

---DOCME
-- @pgroup group
-- @ptable[opt] opts
-- @treturn DisplayGroup G
function M.Keyboard (group, opts)
	return _Keyboard_XY_(group, 0, 0, opts)
end

---DOCME
-- @pgroup group
-- @tparam number|dsl_coordinate x
-- @tparam number|dsl_coordinate y
-- @ptable[opt] opts
-- @treturn DisplayGroup G
function M.Keyboard_XY (group, x, y, opts)
	--
	local no_drag, skin, type

	if opts then
		no_drag = opts.no_drag
		skin = opts.skin
		type = opts.type
	end

	skin = skins.GetSkin(skin)

	--
	local Keyboard = display.newGroup()
	local backdrop = display.newRoundedRect(Keyboard, 0, 0, 1, 1, layout.ResolveX(skin.keyboard_backdropborderradius))

	if not no_drag then
		backdrop:addEventListener("touch", BackTouch)
	end

	--
	local xsep, ysep = layout_dsl.EvalDims(skin.keyboard_xsep, skin.keyboard_ysep)
	local x0, y0, bh, w, h = xsep, ysep, -1, layout_dsl.EvalDims(skin.keyboard_keywidth, skin.keyboard_keyheight)

	--
	if type ~= "nums" then
		x0, bh = DoRows(Keyboard, skin.keyboard_keyskin, Chars, x0, y0, w, h, xsep, ysep)
	end

	--
	if type ~= "chars" then
		local rx, rh = DoRows(Keyboard, skin.keyboard_keyskin, Nums, x0, y0, w, h, xsep, ysep)

		x0, bh = rx, max(bh, rh)
	end

	--
	local rx, rh = DoRows(Keyboard, skin.keyboard_keyskin, Other, x0, y0, w, h, xsep, ysep)

	x0, bh = rx, max(bh, rh)

	--
	layout_dsl.PutObjectAt(Keyboard, x, y)

	group:insert(Keyboard)

	--
	backdrop.strokeWidth = skin.keyboard_backdropborderwidth
	backdrop.width, backdrop.height = x0, bh

	backdrop:setFillColor(colors.GetColor(skin.keyboard_backdropcolor))
	backdrop:setStrokeColor(colors.GetColor(skin.keyboard_backdropbordercolor))
	backdrop:translate(backdrop.width / 2, backdrop.height / 2)

	return Keyboard
end

-- Main keyboard skin --
skins.AddToDefaultSkin("keyboard", {
	backdropcolor = { type = "gradient", color1 = { .25 }, color2 = { .75 }, direction = "up" },
	backdropbordercolor = "white",
	backdropborderwidth = 2,
	backdropborderradius = "1%",
	keyskin = nil,
	keywidth = "5%",
	keyheight = "8.33%",
	xsep = ".625%",
	ysep = "1.42%"
})

-- Cache module members.
_Keyboard_XY_ = M.Keyboard_XY

-- Export the module.
return M