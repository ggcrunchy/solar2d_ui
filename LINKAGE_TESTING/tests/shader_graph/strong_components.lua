--- Utility for finding and using strong components in a graph.

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

-- Exports --
local M = {}

--
--
--

local Preorder, Low = {}

local function HasVisited (index)
    local pn = Preorder[index] or Low

    return pn > Low, pn
end

local Stack, Top = {}, 0

local Path, Length = {}, 0

local Count = 0

local ComponentID = 0

-- Adapted from Sedgewick's "Algorithms in C++, 3rd edition: part 5, Graph Algorithms"
local function AuxBuild (graph, adj_iter, ids, w)
	Count = Count + 1
	Preorder[w] = Count

	Stack[Top + 1], Top = w, Top + 1
	Path[Length + 1], Length = w, Length + 1

	for _, t in adj_iter(graph, w) do
		local visited, preorder = HasVisited(t)

		if not visited then
			AuxBuild(graph, adj_iter, ids, t)
		elseif not ids[t] then -- visited, but not yet assigned to a component?
			for j = Length, 1, -1 do
				if Preorder[Path[j]] <= preorder then
					Length = j

					break
				end
			end
		end
	end

	if Path[Length] == w then -- nothing left to explore?
		Length = Length - 1

		repeat
			local v = Stack[Top]

			ids[v], Top = ComponentID, Top - 1
		until v == w -- w being what we pushed up top
	 
		ComponentID = ComponentID + 1
	end
end

local function DefAdjacencyIter (graph, index)
    return ipairs(graph[index])
end

local function AuxDefTopLevelIter (forest, index)
    index = index + 1

    return forest[index] and index, forest, index
end

local function DefTopLevelIter (forest)
    return AuxDefTopLevelIter, forest, 0
end

local LowID

--- Compute strongly connected components using Gabow's path-based algorithm.
--
-- This follows a depth-first search, starting with a set of top level objects. Each object
-- must have some user-defined "index" that uniquely identifies it.
-- @tparam Forest forest One or more graphs comprising the objects to strongly connect.
-- @ptable[opt] opts Computation options, which may include:
--
-- * **adjacency\_iter**: If present, called as `for _, neighbor_index in adjacency_iter(graph, object_index) do`
-- to iterate through the neighbors of an object, with _graph_ coming from the top level.
--
-- The default assumes that _forest_ is an array such as `{}, {1,3}, {1,2}`, where each table
-- is an object, an object's index is its position in the array, and each object's array
-- part consists of its neighbor indices.
-- * **top\_level\_iter**: If present, called as `for _, graph, object_index in top_level_iter(forest) do`
-- to get the top-level objects and the subgraphs to which each belongs.
--
-- The default assumes the same structure as *adjacency\_iter* and will walk the whole array,
-- supplying it as _graph_ at each step.
-- * **out**: If present, a table that will be populated and used as the return value.
-- @treturn table A map from object indices to strong component IDs.
-- @treturn uint Number of strongly connected components.
-- @treturn uint Lowest valid component ID in the results. When supplying an output table, any
-- entries left unwritten will have lower IDs and should be ignored.
function M.Gabow (forest, opts)
	local adj_iter, tl_iter, ids

    if opts then
        adj_iter, tl_iter, ids = opts.adjacency_iter, opts.top_level_iter, opts.out
    end

    Low, LowID, adj_iter, ids = Count, ComponentID, adj_iter or DefAdjacencyIter, ids or {}

	for _, graph, index in (tl_iter or DefTopLevelIter)(forest) do
		if not HasVisited(index) then
			AuxBuild(graph, adj_iter, ids, index)
		end
	end

	return ids, ComponentID - LowID, LowID
end

--- Get an unused component ID, e.g. for new or singleton objects.
-- @treturn uint ID.
function M.NewID ()
	ComponentID = ComponentID + 1

	return ComponentID
end

---
-- @ptable ids A map from object indices to strong component IDs, as returned by @{Gabow}.
-- @param index1 Index of object #1...
-- @param index2 ...and #2.
-- @treturn boolean The objects are part of the same strong component?
function M.StronglyReachable (ids, index1, index2)
	return ids[index1] == ids[index2]
end

return M