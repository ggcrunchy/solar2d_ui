--- Some useful UI patterns based around editable strings.

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
local char = string.char
local concat = table.concat
local floor = math.floor
local gmatch = string.gmatch
local lower = string.lower
local max = math.max
local sub = string.sub
local tonumber = tonumber
local tostring = tostring
local upper = string.upper

-- Modules --
local cursor = require("corona_ui.utils.cursor")
local keyboard = require("corona_ui.widgets.keyboard")
local layout = require("corona_ui.utils.layout")
local net = require("corona_ui.patterns.net")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local layout_strategies = require("corona_ui.utils.layout_strategies")
local meta = require("tektite_core.table.meta")
local scenes = require("corona_utils.scenes")

-- Corona globals --
local display = display
local easing = easing
local native = native
local timer = timer
local transition = transition

-- Exports --
local M = {}

--
--
--

local WidthTest, ScaleToAverageWidth, Widest, WidestChar = display.newText("", 0, 0, native.systemFontBold, 20), 0, 0, ""

WidthTest.isVisible = false

timer.performWithDelay(50, function(event)
	local base = (event.count - 1) * 32

	for i = base, base + 31 do
		local wc = char(i)

		WidthTest.text = wc .. wc

		local w = WidthTest.width

		if w > Widest then
			Widest, WidestChar = w, wc
		end

		ScaleToAverageWidth = ScaleToAverageWidth + w
	end

	if base + 32 == 256 then
		WidthTest:removeSelf()

		ScaleToAverageWidth, WidthTest = ScaleToAverageWidth / (Widest * 256)
	end
end, 8)

--
local function Char (name, is_shift_down)
	--
	if name == "space" then
		return " "
	elseif name == "-" and is_shift_down then
		return "_"

	--
	elseif #name == 1 then -- what about UTF8?
		local ln, un = lower(name), upper(name)

		if ln ~= name then
			return is_shift_down and ln or name
		elseif un ~= name then
			return is_shift_down and un or name
		end
	end
end

--
local function Num (name)
	if name == "." or tonumber(name) then
		return name
	end
end

-- ^^^ Allows multiple decimal points in string (also issue with keyboard, not sure about native)

--
local function Any (name, is_shift_down)
	return Char(name, is_shift_down) or Num(name)
end

--
local function AdjustAndClamp (info, n, how)
	local remove_at, new_pos = info.m_pos

	if how == "dec" then
		new_pos = remove_at > 0 and remove_at - 1
	elseif remove_at < n then
		if how == "inc" then
			new_pos = remove_at + 1
		else
			new_pos, remove_at = remove_at, remove_at + 1
		end
	end

	if new_pos then
		return new_pos, remove_at
	end
end

-- Event packet --
local Event = {}

local function ChangeText (old, new, str)
	if old ~= new then
		Event.old_text, Event.new_text, Event.name, Event.target = old, new, "text_change", str.parent

		str.parent:dispatchEvent(Event)

		Event.target = nil
	end
end

local function SetStringText (editable, str, text)
	local nchars = editable.m_nchars

	if #text > nchars then
		str.text, editable.m_text = text:sub(1, nchars - 3) .. "...", text
	else
		str.text, editable.m_text = text
	end
end

local function AuxGetText (editable, str)
	return editable.m_text or str.text
end

--
local function SetText (str, text, align, w)
	local editable = str.parent
	local old, set_text = AuxGetText(editable, str), str.m_set_text

	if set_text and not str.m_use_raw then
		editable.m_text = nil

		set_text(editable, text)
	else
		SetStringText(editable, str, text)
	end

	if align == "left" then
		layout.LeftAlignWith(str, ".25%")
	elseif align == "right" then
		layout.RightAlignWith(str, w, "-.25%")
	end

	ChangeText(old, AuxGetText(editable, str), str)
end

--
local function UpdateCaret (info, str, pos)
	if pos then
		info.m_pos = pos

		layout.LeftAlignWith(info.parent:GetCaret(), str, cursor.GetOffset(str, pos))
	end
end

--- ^^ COULD be stretched to current character width, by taking difference between it and next character,
-- or rather the consecutive substrings they define (some default width at string end)

-- --
local KeyType = {}

for gname, group in pairs{
	delete = { "deleteBack", "deleteForward" },
	horz_move = { "end", "home", "left", "right" },
	vert_move = { "down", "pageDown", "pageUp", "up" }
} do
	for i = 1, #group do
		KeyType[group[i]] = gname
	end
end

--
local function DoKey (info, name, is_shift_down)
	local str = info.parent:GetString()
	local text, gname = str.text, KeyType[name]

	--
	if gname == "delete" then
		local new_pos, remove_at = AdjustAndClamp(info, #text, name == "deleteBack" and "dec")

		if remove_at then
			text = sub(text, 1, remove_at - 1) .. sub(text, remove_at + 1)

			SetText(str, text, info.m_align, info.m_width)
			UpdateCaret(info, str, new_pos)
		end

	--
	elseif gname == "horz_move" then
		local pos

		if name == "left" or name == "right" then
			pos = AdjustAndClamp(info, #text, name == "left" and "dec" or "inc")
		else
			pos = name == "home" and 0 or #text
		end

		UpdateCaret(info, str, pos)

	--
	elseif gname == "vert_move" then
		-- TODO! (multiline)

	--
	else
-- Tab?
		local result, pos = (info.m_filter or Any)(name, is_shift_down), info.m_pos

		if result then
			text = sub(text, 1, pos) .. result .. sub(text, pos + 1)

			SetText(str, text, info.m_align, info.m_width)
			UpdateCaret(info, str, pos + 1)
		else
			return false
		end
	end

	return true
end

-- --
local OldListenFunc

-- --
local Current

-- --
local FadeAwayParams = { alpha = 0, onComplete = display.remove }

-- --
local KeyFadeOutParams = {
	alpha = .2,

	onComplete = function(object)
		object.isVisible = false
	end
}

--
local function CloseKeysAndText (by_key)
	--
	Event.name, Event.target, Event.closed_by_key = "closing", Current, not not by_key

	Current:dispatchEvent(Event)

	Event.target = nil

	--
	scenes.SetListenFunc(OldListenFunc)
	transition.to(Current.m_net, FadeAwayParams)

	if Current.m_stub then
		local caret = Current:GetCaret()

		transition.cancel(caret)

		caret.isVisible = false

		net.RestoreAfterHoist(Current, Current.m_stub)
	else
		Current.m_textfield:removeSelf()
	end

	--
	local keys = Current:GetKeyboard()

	Current, OldListenFunc, Current.m_net, Current.m_stub, Current.m_textfield = nil

	if keys then
		transition.to(keys, KeyFadeOutParams)
	end
end

--
local function HandleKey (event)
	local name = event.keyName

	--
	if event.isCtrlDown then
		return

	--
	elseif name ~= "enter" then
		for i = 1, Current.numChildren do
			local item = Current[i]

			if item.m_pos then
				--
				if event.phase == "down" then
					local is_shift_down = event.isShiftDown

					if not item.m_timer and DoKey(item, name, is_shift_down) then
						item.m_timer, item.m_key = timer.performWithDelay(350, function()
							DoKey(item, name, is_shift_down)
						end, 0), name
					end

				--
				elseif item.m_key == name then
					timer.cancel(item.m_timer)

					item.m_key, item.m_timer = nil
				end

				break
			end
		end

	--
	elseif event.phase == "down" then
		CloseKeysAndText(true)
	end

	return true
end

--
local function Listen (what, event)
	if what == "message:handles_key" then
		HandleKey(event)
	end
end

-- --
local Filter = { chars = Char, nums = Num }

-- --
local CaretParams = { time = 650, iterations = -1, alpha = .125, transition = easing.continuousLoop }

-- --
local FadeInParams = { alpha = .4 }

-- --
local KeyFadeInParams = { alpha = 1 }

-- --
local XSep, YSep = layout_dsl.EvalDims(".625%", "1.04%")

-- --
local PlaceKeys = { "below", "above", "bottom_center", "top_center", dx = XSep, dy = YSep }

-- --
local BlockerOpts = {
	gray = .4, alpha = .3,

	on_touch = function(event)
		local net = event.target

		if net.m_fading then -- ignore quick touches during fadeaway
			return false
		elseif event.phase == "ended" or event.phase == "cancelled" then
			CloseKeysAndText(false)

			net.m_fading = true
		end

		return true
	end
}

local function GetText ()
	if Current.m_get_text then
		return tostring(Current:m_get_text() or "")
	else
		return Current:GetText()
	end
end

local function Submit ()
	Current:SetText(Current.m_textfield.text)

	CloseKeysAndText(true)
end

local function UserInput (event)
	if event.phase == "submitted" then
		Submit() -- TODO: On Android, defer?
	end
end

--
local function EnterInputMode (editable)
	Current, OldListenFunc = editable

	--
	local caret, listen = editable:GetCaret()

	if caret then
		listen, editable.m_stub, editable.m_net = Listen, net.HoistOntoStage(editable, CloseKeysAndText, editable.m_blocking)
	else
		local bounds = editable.contentBounds
		local xmin, ymin, xmax, ymax = bounds.xMin, bounds.yMin, bounds.xMax, bounds.yMax

		editable.m_net = net.Blocker(display.getCurrentStage(), BlockerOpts)
		editable.m_textfield = native.newTextField((xmin + xmax) / 2, (ymin + ymax) / 2, xmax - xmin, ymax - ymin)

		editable.m_textfield.text = GetText()

		editable.m_textfield:addEventListener("userInput", UserInput)

		if editable.m_input_type then
			editable.m_textfield.inputType = editable.m_input_type
		end

		native.setKeyboardFocus(editable.m_textfield)
	end

	OldListenFunc = scenes.SetListenFunc(listen)

	--
	local keys = editable:GetKeyboard()

	if keys then
		keys:toFront()
	end

	--
	editable.m_net.alpha = .01

	transition.to(editable.m_net, FadeInParams)

	if caret then
		transition.to(caret, CaretParams)

		caret.alpha, caret.isVisible = .6, true
	end

	if keys then
		layout_strategies.PutAtFirstHit(keys, editable, PlaceKeys, true)

		keys.alpha, keys.isVisible = .2, true

		transition.to(keys, KeyFadeInParams)
	end
end

--
local function Touch (event)
	local phase, editable = event.phase, event.target.parent
	local using_textfield = editable:GetCaret() == nil

	if phase == "began" then
		if Current then
			local str = editable:GetString()
			local pos = cursor.GetPosition_GlobalXY(str, event.x, event.y)

			UpdateCaret(cursor.GetProxy(str), str, pos)

			-- TODO: detect drags
		elseif not using_textfield then
			EnterInputMode(editable)
		end
	elseif using_textfield and (phase == "ended" or phase == "cancelled") then
		EnterInputMode(editable)
	end

	return true
end

-- TODO: Handle taps in text case? (then need to pinpoint position...)
-- Needs to handle all three alignments, too

-- --
local CharWidthForFont = meta.Weak("k")

local function Finalize (event)
	local editable = event.target

	display.remove(editable.m_keys)
	display.remove(editable.m_net)
	display.remove(editable.m_stub)
end

-- --
local Editable = {}

--- DOCME
function Editable:EnterInputMode ()
	if not Current then
		EnterInputMode(self)
	end
end

--- DOCME
function Editable:GetCaret ()
	return self.m_caret
end

--- DOCME
function Editable:GetChildOfParent ()
	return self.m_stub or self
end

--- DOCME
function Editable:GetKeyboard ()
	return self.m_keys
end

--- DOCME
function Editable:GetString ()
	return self.m_str
end

--- DOCME
function Editable:GetText ()
	return AuxGetText(self, self.m_str)
end

--- DOCME
function Editable:SetStringText (text)
	SetStringText(self, self.m_str, tostring(text))
end

--- DOCME
function Editable:SetText (text)
	text = tostring(text)

	local info = self.m_info
	local filter = info and info.m_filter

	if filter then
		local chars

		for char in gmatch(text, ".") do
			chars = chars or {}
			chars[#chars + 1] = filter(char)
		end

		text = chars and concat(chars, "") or ""
	end

	SetText(self.m_str, text, self.m_align, self.m_w)
end

--- DOCME
function Editable:UseRawText (use_raw)
	local info, str = self.m_info, self.m_str
	local became_raw = not str.m_use_raw and use_raw

	str.m_use_raw = not not use_raw

	if became_raw then
		SetText(str, self:GetText(), info and info.m_align, info and info.m_width)
	end
end

--
local function AuxEditable (group, x, y, opts)
	local editable = display.newGroup()

	editable.anchorChildren = true

	--
	local text, font, size = tostring(opts and opts.text or ""), opts and opts.font or native.systemFontBold, layout.ResolveY(opts and opts.size or "4.2%")

	--
	editable.m_blocking = not not (opts and opts.blocking)

	--
	local style, caret, str, info = opts and opts.style

	if style == "text_only" or style == "keys_and_text" then
		caret = display.newRect(editable, 0, 0, XSep, str.height)

		layout.PutRightOf(caret, str)

		caret.isVisible, str, info = false, cursor.NewText(editable, "", 0, 0, font, size)
	else
		str = display.newText(editable, "", 0, 0, font, size)

		editable.m_get_text = opts and opts.get_editable_text
	end

	local align, ow, oh = opts and opts.align, layout_dsl.EvalDims(opts and opts.width or 0, opts and opts.height or 0)

	if opts and opts.adjust_to_size then
		str.text = text
		str.text, ow, oh = "", max(ow, str.width), max(ow, str.height)

		local max_adjust = layout.ResolveX(opts.max_adjust_width)

		if ow > max_adjust then
			ow = max_adjust
		end
	end

	local w, h = max(ow, layout.ResolveX("10%")), max(oh, layout.ResolveY("5.2%"))

	if not CharWidthForFont[font] then
		str.text = WidestChar
		str.text, CharWidthForFont[font] = "", str.width * ScaleToAverageWidth
	end

	editable.m_nchars = max(floor(w / CharWidthForFont[font]), 4)

	SetText(str, text, align, w)

	str.m_set_text = opts and opts.set_editable_text

	if info then
		editable.m_info, info.m_align, info.m_pos, info.m_width = info, align, #text, w
	end

	--
	local mode, keys = opts and opts.mode

	if style == "text_only" then
		info.m_filter = Filter[mode]
	elseif style == "keys_and_text" then
		keys = keyboard.Keyboard(display.getCurrentStage(), mode and { type = mode })

		info.m_filter, keys.isVisible = Filter[mode], false
	else
		if mode == "nums" or mode == "decimal" then
			editable.m_input_type = mode == "nums" and "number" or "decimal"
			-- TODO! needs a bit of testing
		end
	end

	--
	local body = display.newRoundedRect(editable, 0, 0, w + XSep, h + YSep, layout.ResolveX("1.5%"))

	body:addEventListener("touch", Touch)
	body:setFillColor(0, 0, .9, .6)
	body:setStrokeColor(.125)
	body:toBack()

	body.strokeWidth = 2

	--
	layout_dsl.PutObjectAt(editable, x, y)

	group:insert(editable)

	--
	editable.m_align, editable.m_caret, editable.m_str, editable.m_w = align, caret, str, w

	if keys or caret == nil then
		editable.m_keys = keys

		editable:addEventListener("finalize", Finalize)
	end

	meta.Augment(editable, Editable)

	return editable
end

--- DOCME
function M.Editable (group, opts)
	return AuxEditable(group, 0, 0, opts)
end

--- DOCME
function M.Editable_XY (group, x, y, opts)
	return AuxEditable(group, x, y, opts)
end

-- Export the module.
return M