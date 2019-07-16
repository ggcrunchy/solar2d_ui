--- Undo-redo stack test.

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

local urs = require("s3_editor.UndoRedoStack")

local stack = urs.New(11)

local function UR (how, arg)
	if how == "redo" then
		print("REDO", arg)
	else
		print("UNDO", arg)
	end
end

for i = 1, 9 do
	stack:Push(UR, i)
end

vdump(stack) -- TODO: hook this up...

print("")
print("UNDOING:")
print("")

for _ = 1, 11 do
	if not stack:Undo() then
		print("Nothing to undo")
	end
end

print("")

vdump(stack)

print("")
print("REDOING")
print("")

for _ = 1, 11 do
	if not stack:Redo() then
		print("Nothing to redo")
	end
end

print("")

vdump(stack)

for i = 10, 14 do
	stack:Push(UR, i)
end

print("")

vdump(stack)

print("")

for _ = 1, 6 do
	stack:Undo()
end

print("")

vdump(stack)

for i = 1, 4 do
	stack:Push(UR, "ERR" .. i)
end

print("")

vdump(stack)