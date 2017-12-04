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
local concat = table.concat
local gmatch = string.gmatch
local lower = string.lower
local max = math.max
local sub = string.sub
local tonumber = tonumber
local upper = string.upper

-- Modules --
local cursor = require("corona_ui.utils.cursor")
local keyboard = require("corona_ui.widgets.keyboard")
local layout = require("corona_ui.utils.layout")
local net = require("corona_ui.patterns.net")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local layout_strategies = require("corona_ui.utils.layout_strategies")
local scenes = require("corona_utils.scenes")

-- Corona globals --
local display = display
local easing = easing
local native = native
local system = system
local timer = timer
local transition = transition

-- Exports --
local M = {}

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
	Event.old_text, Event.new_text, Event.name, Event.target = old, new, "text_change", str.parent

	str.parent:dispatchEvent(Event)

	Event.target = nil
end

--
local function SetText (str, text, align, w)
	local old = str.text or ""

	str.text = text

	if align == "left" then
		layout.LeftAlignWith(str, ".25%")
	elseif align == "right" then
		layout.RightAlignWith(str, w, "-.25%")
	end

	-- Alert listeners.
	if old ~= text then
		ChangeText(old, text, str)
	end
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
local Editable

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
	Event.name, Event.target, Event.closed_by_key = "closing", Editable, by_key ~= nil

	Editable:dispatchEvent(Event)

	Event.target = nil

	--
	scenes.SetListenFunc(OldListenFunc)
	transition.to(Editable.m_net, FadeAwayParams)

	if Editable.m_stub then
		local caret = Editable:GetCaret()

		transition.cancel(caret)

		caret.isVisible = false

		net.RestoreAfterHoist(Editable, Editable.m_stub)
	else
		Editable.m_textfield:removeSelf()
	end

	--

	Editable, OldListenFunc, Editable.m_net, Editable.m_stub, Editable.m_textfield = nil

	--
	local keys = Editable:GetKeyboard()

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
		for i = 1, Editable.numChildren do
			local item = Editable[i]

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

	on_touch = function()
		CloseKeysAndText(false)
	end
}

local function Submit ()
	local str = Editable:GetString()

	ChangeText(str.text, Editable.m_textfield.text, str)
	CloseKeysAndText(true)
end

local function UserInput (event)
	if event.phase == "submitted" then
		Submit() -- TODO: On Android, defer?
	end
end

--
local function EnterInputMode (editable)
	Editable, OldListenFunc = editable

	--
	local caret, listen = editable:GetCaret()

	if caret then
		listen, editable.m_stub, editable.m_net = Listen, net.HoistOntoStage(editable, CloseKeysAndText, editable.m_blocking)
	else
		local bounds = Editable.contentBounds
		local xmin, ymin, xmax, ymax = bounds.xMin, bounds.yMin, bounds.xMax, bounds.yMax

		editable.m_net = net.Blocker(display.getCurrentStage(), BlockerOpts)
		editable.m_textfield = native.newTextField((xmin + xmax) / 2, (ymin + ymax) / 2, xmax - xmin, ymax - ymin)

		editable.m_textfield:addEventListener("userInput", UserInput)

		if editable.m_get_text then
			editable.m_textfield.text = editable.m_get_text(editable) or ""
		else
			editable.m_textfield.text = editable:GetString().text
		end

		if editable.m_input_type then
			editable.m_textfield.inputType = editable.m_input_type
		end
	end

	OldListenFunc = scenes.SetListenFunc(listen)

	--
	local keys = editable:GetKeyboard()

	if keys then
		keys:toFront()
	end

	--
	Editable.m_net.alpha = .01

	transition.to(Editable.m_net, FadeInParams)

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
	if event.phase == "began" then
		if Editable then
			local str = event.target.parent:GetString()
			local pos = cursor.GetPosition_GlobalXY(str, event.x, event.y)

			UpdateCaret(cursor.GetProxy(str), str, pos)

			-- TODO: detect drags
		else
			EnterInputMode(event.target.parent)
		end
	end

	return true
end

-- TODO: Handle taps in text case? (then need to pinpoint position...)
-- Needs to handle all three alignments, too

--
local function AuxEditable (group, x, y, opts)
	local Editable = display.newGroup()

	Editable.anchorChildren = true

	--
	local text, font, size = opts and opts.text or "", opts and opts.font or native.systemFontBold, layout.ResolveY(opts and opts.size or "4.2%")

	--
	Editable.m_blocking = not not (opts and opts.blocking)

	--
	local style, caret, str, info = opts and opts.style

	if style == "text_only" or style == "keys_and_text" then
		caret = display.newRect(Editable, 0, 0, XSep, str.height)

		layout.PutRightOf(caret, str)

		caret.isVisible, str, info = false, cursor.NewText(Editable, text, 0, 0, font, size)
	else
		str = display.newText(Editable, text, 0, 0, font, size)

		Editable.m_get_text = opts and opts.get_editable_text
	end

	local align, ow, oh = opts and opts.align, layout_dsl.EvalDims(opts and opts.width or 0, opts and opts.height or 0)
	local w, h = max(str.width, ow, layout.ResolveX("10%")), max(str.height, oh, layout.ResolveY("5.2%"))

	SetText(str, str.text, align, w)

	if info then
		info.m_align, info.m_pos, info.m_width = align, #text, w
	end

	--
	local mode, keys = opts and opts.mode
--	local platform = system.getInfo("platform")
--	local on_desktop = platform == "macos" or platform == "win32" or system.getInfo("environment") == "simulator"

	if style == "text_only" then
		info.m_filter = Filter[mode]
	elseif style == "keys_and_text"--[[ or on_desktop]] then
		keys = keyboard.Keyboard(display.getCurrentStage(), mode and { type = mode })

		info.m_filter, keys.isVisible = Filter[mode], false
	else
		if mode == "nums" then
			Editable.m_input_type = "decimal"
		elseif mode == "ints" then
			-- TODO! (all of this needs a lot of testing)
		end
	end

	--
	local body = display.newRoundedRect(Editable, 0, 0, w + XSep, h + YSep, layout.ResolveX("1.5%"))

	body:addEventListener("touch", Touch)
	body:setFillColor(0, 0, .9, .6)
	body:setStrokeColor(.125)
	body:toBack()

	body.strokeWidth = 2

	--
	layout_dsl.PutObjectAt(Editable, x, y)

	group:insert(Editable)

	--- DOCME
	function Editable:GetCaret ()
		return caret
	end

	--- DOCME
	function Editable:GetChildOfParent ()
		return self.m_stub or self
	end

	--- DOCME
	function Editable:GetKeyboard ()
		return keys
	end

	--- DOCME
	function Editable:GetString ()
		return str
	end

	--- DOCME
	function Editable:EnterInputMode ()
		if not Editable then
			EnterInputMode(self)
		end
	end

	--- DOCME
	function Editable:SetText (text)
		local filter = info and info.m_filter

		if filter then
			local chars

			for char in gmatch(text, ".") do
				chars = chars or {}
				chars[#chars + 1] = filter(char)
			end

			text = chars and concat(chars, "") or ""
		end

		SetText(str, text, align, w)
	end

	--
	if keys or caret == nil then
		Editable:addEventListener("finalize", function(event)
			display.remove(keys)
			display.remove(event.target.m_net)
			display.remove(event.target.m_stub)
		end)
	end

	return Editable
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