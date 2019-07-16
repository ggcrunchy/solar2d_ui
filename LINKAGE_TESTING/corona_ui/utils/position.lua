--- Some utilities for positions within the display hierarchy.

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

-- Corona globals --
local display = display

-- Cached module references --
local _IndexInGroup_

-- Exports --
local M = {}

--
--
--

local Paths = {}

local function GetFrontmostPathAtDepth (nleft, depth)
    -- An example situation:
    --
    -- 1 -> 2 -> 3 -> 4 -> 5 -> 6 (children of the stage)
    --                ^
    --                |            At depth = 1, all objects still have a common ancestor, the group at index = 4
    --                1 -> 2 -> 3
    --                ^         ^
    --                |         |  At depth = 2, the group at index = 3 is frontmost
    --               ...        1
    -- At depth = 3, only one possibility remains (path 1 -> 1 -> 4), so this is the foremost object
    local frontmost = 0

    for i = 1, nleft do
        local path = Paths[i]
        local index = path[path.height - depth]

        if index > frontmost then
            frontmost = index
        end
    end

    return frontmost
end

local function RemoveNonFrontmostPathsAtDepth (nleft, depth, frontmost)
    for i = nleft, 1, -1 do
        local path = Paths[i]
        local index = path[path.height - depth]

        if index < frontmost then
            nleft, Paths[i], Paths[nleft] = nleft - 1, Paths[nleft], path
        end
    end

    return nleft
end

local function GetPath (index)
    return Paths[index] or { [0] = 0 } -- 0 index visited if we traverse full height; will always be behind frontmost index
end

--- DOCME
function M.Frontmost (objects, n)
    n = n or #objects

    if n <= 1 then
        return objects[1]
    else
        local stage, top = display.getCurrentStage()

        for i = 1, n do
            local path, cur, height = GetPath(i), assert(objects[i], "Invalid object"), 0

            while cur ~= stage and cur ~= nil do -- iterate up to stage or canvas
                cur, height, path[height + 1] = cur.parent, height + 1, _IndexInGroup_(cur)
            end

            if i == 1 then
                top = cur
            elseif top ~= cur then -- objects not all in same hierarchy?
                return false
            end

            Paths[i], path.height, path.object_index = path, height, i
        end

        local nleft, depth = n, 0

        repeat
            local frontmost = GetFrontmostPathAtDepth(nleft, depth)

            depth, nleft = depth + 1, RemoveNonFrontmostPathsAtDepth(nleft, depth, frontmost)
        until nleft == 1

        return objects[Paths[1].object_index]
    end
end

--- DOCME
function M.IndexInGroup (object)
    local parent = object.parent

    if parent then
        for i = 1, parent.numChildren do
            if parent[i] == object then
                return i
            end
        end
    else
        return nil
    end
end

_IndexInGroup_ = M.IndexInGroup

return M