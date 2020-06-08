//step 1
WITH [1, 2, 5] as selection
MATCH (v:Vertex)
WHERE v.number in selection
WITH collect(v) as vertices
UNWIND vertices as v1
WITH
	v1,
    [v in vertices where v.number > v1.number] as v2s,
    vertices
UNWIND v2s as v2
CALL algo.shortestPath.stream(
	v1,
    v2,
    'cost',
    {relationshipQuery: 'LINK_TO'}
)
YIELD nodeId, cost
WITH
	v1,
    v2,
    max(cost) as totalCost,
    collect(nodeId) as shortestHopNodeIds,
    vertices
MERGE (v1)-[r:SHORTEST_ROUTE_TO]-(v2)
SET r.cost = totalCost
SET r.shortestHopNodeIds = shortestHopNodeIds
//step 2
WITH
	v1,
    v2,
    (size(vertices) - 1) as level,
    vertices
CALL apoc.path.expandConfig(
	v1,
    {
    	relationshipFilter: 'SHORTEST_ROUTE_TO',
        minLevel: level,
        maxLevel: level,
        whitelistNodes: vertices,
        terminatorNodes: [v2],
        uniqueness: 'NODE_PATH'
    }
)
YIELD path
WITH 
	nodes(path) as orderedVertices,
	[n in nodes(path) | id(n)] as ids, 
	reduce(cost = 0, x in relationships(path) | cost + x.cost) as totalCost,
	[r in relationships(path) | r.shortestHopNodeIds] as shortestRouteNodeIds 
ORDER BY totalCost LIMIT 1 
//step3
UNWIND range(0, size(orderedVertices) - 1) as index
UNWIND shortestRouteNodeIds[index] as shortestHopNodeId
WITH
	orderedVertices,
    totalCost,
    index,
    CASE
    	WHEN shortestRouteNodeIds[index][0] = ids[index]
        THEN tail(collect(shortestHopNodeId))
        ELSE tail(reverse(collect(shortestHopNodeId)))
        END as orderedHopNodeIds
ORDER BY index
UNWIND orderedHopNodeIds as orderedHopNodeId
MATCH (v:Vertex) where id(v) = orderedHopNodeId
RETURN
	[v in orderedVertices | v.number] as Id,
    [orderedVertices[0].number] + collect(v.number) as vertexRoute,
    totalCost
