--- Utility for finding and using strong components in a graph.
--
-- Adapted from Sedgewick's "Algorithms in C++, 3rd edition: part 5, Graph Algorithms".

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
local dfs = require("tests.shader_graph.dfs")

-- Exports --
local M = {}

--
--
--

local Gabow = dfs.NewAlgorithm()

local Path, Length = {}, 0

local function TrimPath (t, preorder, ids)
	if not ids[t] then -- visited, but not yet assigned to a component?
		for j = Length, 1, -1 do
			if dfs.GetPreorderNumber(Gabow, Path[j]) <= preorder then
				Length = j

				break
			end
		end
	end
end

local Stack, Top = {}, 0

local ComponentID = 0

local function DoVertex (graph, w, adj_iter, ids)
	Stack[Top + 1], Top = w, Top + 1
	Path[Length + 1], Length = w, Length + 1

	dfs.VisitAdjacentVertices(Gabow, DoVertex, TrimPath, graph, w, adj_iter, ids)

	if Path[Length] == w then -- nothing left to explore?
		repeat
			local v = Stack[Top]

			ids[v], Top = ComponentID, Top - 1
		until v == w

		ComponentID, Length = ComponentID + 1, Length - 1
	end
end

local LowID

--- Compute strongly connected components using Gabow's path-based algorithm.
--
-- This follows a depth-first search, starting with a set of top-level vertices. Each vertex
-- must have some user-defined "index" that uniquely identifies it.
-- @param top_level_vertices Vertices to strongly connect.
-- @ptable[opt] opts Computation options, which may include:
--
-- * **adjacency\_iter**: If present, called as `for _, neighbor_index in adjacency_iter(graph, vertex_index) do`
-- to iterate through a vertex's neighbors, with _graph_ coming from the top level.
--
-- The default assumes that _top\_level\_vertices_ is an array such as `{}, {1,3}, {1,2}`, where each table
-- is a vertex, a vertex's index is its position in this array, and each vertex's array
-- part consists of its neighbor indices.
-- * **top\_level\_iter**: If present, called as `for _, graph, vertex_index in top_level_iter(top_level_vertices) do`
-- to get the top-level vertices and the subgraphs to which each belongs.
--
-- The default assumes the same structure as *adjacency\_iter* and will walk the whole array,
-- supplying it as _graph_ at each step.
-- * **out**: If present, a table that will be populated and used as the return value.
-- @treturn table A map from vertex indices to strong component IDs.
-- @treturn uint Number of strongly connected components.
-- @treturn uint Lowest valid component ID in the results. When supplying an output table, any
-- entries left unwritten will have lower IDs and should be ignored.
function M.Gabow (top_level_vertices, opts)
	local ids = opts and opts.out or {}

    LowID = ComponentID

	dfs.VisitTopLevel(Gabow, DoVertex, top_level_vertices, opts, ids)

	return ids, ComponentID - LowID, LowID
end

--- Get an unused component ID, e.g. for new or singleton vertices.
-- @treturn uint ID.
function M.NewID ()
	ComponentID = ComponentID + 1

	return ComponentID
end

---
-- @ptable ids A map from vertex indices to strong component IDs, as returned by @{Gabow}.
-- @param index1 Index of vertex #1...
-- @param index2 ...and #2.
-- @treturn boolean The vertices belong to the same strong component?
function M.StronglyReachable (ids, index1, index2)
	return ids[index1] == ids[index2]
end

return M