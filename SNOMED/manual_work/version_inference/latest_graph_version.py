def _main(

        mv_dependency_graph,  # Input: varchar[], where each element
                              # is a string of the form
                              # "module==version->dependency==version"

        newest_wanted = [     # Input: varchar[], where each element
        "900000000000207008", # is a string of the moduleids that
        "731000124108",       # the user wants the newest version of.
        "999000011000000103",
        ],

        release_version =     # Input: int, the YYYMMDD version of the
            20231101          # release that the user wants to build.
                              # Will look for modules up to 9 months old.

    ):                        # Returns:
                              # varchar[][], where each element is an array of
                              # strings of the form "module==version"
    """\
    Return all versions combos of each module so
    that they can form a valid graph.
    """
    from typing import Set, List, Tuple, Dict, Generator, Optional
    from datetime import datetime, timedelta
    release_date = datetime.strptime(str(release_version), "%Y%m%d")
    min_version = int(
        (release_date - timedelta(days=270)).strftime("%Y%m%d")
    )

    # Helper types:
    Module = str
    Version = int
    VersionedModule = Tuple[Module, Version]
    Dependency = Module
    VersionedDependency = VersionedModule
    Digraph = Dict[Module, Set[Dependency]]
    VersionedDigraph = Dict[VersionedModule, Set[VersionedDependency]]
    ValidatedGraph = Dict[Module, Version]

    #Helper functions:
    def _split_mv(_mv: str) -> VersionedModule:
        m_str, v_str = _mv.split("==")[:2]
        return Module(m_str), Version(v_str)

    def _parse_edge(_edge: str) -> Tuple[VersionedModule, VersionedDependency]:
        module, dependency = _edge.split("->")[:2]
        return _split_mv(module), _split_mv(dependency)

    def _unique_versioned_modules(_graph: VersionedDigraph
            ) -> List[VersionedModule]:
        mvs = []
        for module, dependencies in _graph.items():
            mvs.append(module)
            mvs.extend(dependencies)
        mvs.sort(key=lambda mv: (mv[0], mv[1]))
        return mvs

    def _parse_graph(_graph: List[str]) -> VersionedDigraph:
        edges = [_parse_edge(edge) for edge in _graph]
        graph = {}
        for module, dependency in edges:
            graph.setdefault(module, set()).add(dependency)
        return graph

    def _unvers_graph(_graph: VersionedDigraph) -> Digraph:
        graph = {}
        for mv, dsv in _graph.items():
            graph.setdefault(mv[0], set()).update(d for d, _ in dsv)
        return graph

    def _module_versions(_uvm: List[VersionedModule]
            ) -> Dict[Module, List[Version]]:
        versions = {}
        for module, version in _uvm:
            versions.setdefault(module, []).append(version)

        # Sort versions as newest last, so that they are popped first.
        for vs in versions.values():
            vs.sort(reverse=False)
        return versions

    def _validate_subgraph(_subgraph: VersionedDigraph) -> bool:
        # Validate that the subgraph is valid.
        # That means that it contains a version of each unique module.
        return set(m for m, _ in _subgraph) == (set(unique_modules) | {root})

    def _check_version(_version: Version) -> bool:
        return release_version > _version >= min_version

    def _add_to_graph(node: VersionedModule,
                      graph: VersionedDigraph,
                      constraint: Optional[Dict[Module, Set[Version]]] = None
                    ):
        if constraint is None:
            constraint = {}

        if node in graph:
            return

        if node[0] in [m for m, _ in graph]:
            # Node is already in the graph at another version!
            raise ValueError(f"Node {node} is already in the graph at"
                             f"different version.")

        if node[0] == root:
            # Root is always valid.
            graph[node] = set()
            return

        if node not in VERSIONED_GRAPH:
            # UK module shenanigans
            raise ValueError(f"Dependency {node} can not be added to"
                             f"the graph as it is not a known module "
                             f"version.")

        for dependency in VERSIONED_GRAPH[node]:
            if dependency not in graph:
                if dependency[0] in constraint and \
                        dependency[1] not in constraint[dependency[0]]:
                    # This dependency can not be added to the graph.
                    raise ValueError(f"Dependency {dependency} can not be"
                                     f"added to the graph at required "
                                     f"version")
                _add_to_graph(dependency, graph, constraint)

        graph[node] = VERSIONED_GRAPH[node]

    def _get_checked_versions(node: Module) -> List[VersionedModule]:
        versions = filter(_check_version, unique_modules[node])
        return [(node, version) for version in versions]

    # Parse input graph:
    VERSIONED_GRAPH: VersionedDigraph = _parse_graph(mv_dependency_graph)
    GRAPH: Digraph = _unvers_graph(VERSIONED_GRAPH)

    # Solution functions:
    def _leaf_modules(_graph: Digraph) -> Set[Module]:
        # Leaves only depend, and do not serve as dependencies.
        leaves = set(_graph)
        for _, dependencies in _graph.items():
            leaves.difference_update(dependencies)
        return leaves

    def _root_modules(_graph: Digraph) -> Set[Module]:
        # Roots only serve as dependencies, and do not depend.
        # Since this is SNOMED, there should be only one root.
        all_modules = set()
        for _, dependencies in _graph.items():
            all_modules.update(dependencies)
        roots = set(all_modules).difference(_graph)
        return roots

    leaves = _leaf_modules(GRAPH)
    _roots = _root_modules(GRAPH)
    if len(_roots) != 1:
        print(_roots)
        raise ValueError("There should be only one root. Input is incorrect")
    root = _roots.pop()
    # print(f"Root: {root}")
    # print(f"Leaves: {leaves}")

    # If a node has multiple dependencies on the same module,
    # keep only the newest.
    _new_graph = {}
    for mv, dependencies_v in VERSIONED_GRAPH.items():
        modules = GRAPH[mv[0]]
        new_deps = set()
        for module in modules:
            versions = [v for m, v in dependencies_v if m == module]
            if versions:
                versions.sort()
                new_deps.add((module, versions[-1]))
        _new_graph[mv] = new_deps
    VERSIONED_GRAPH = _new_graph
    unique_versioned_modules = _unique_versioned_modules(VERSIONED_GRAPH)
    unique_modules = _module_versions(unique_versioned_modules)

    # If a node depends on a module at a non-existent version, change the
    # dependency to the next most recent version.
    _new_graph = {}
    for mv, dependencies_v in VERSIONED_GRAPH.items():
        new_deps = set()
        for dependency in dependencies_v:
            if dependency in VERSIONED_GRAPH or dependency[0] == root:
                new_deps.add(dependency)
            else:
                versions = unique_modules[dependency[0]]
                newer_versions = [v for v in versions if v > dependency[1]]
                if newer_versions:
                    newer_versions.sort()
                    new_deps.add((dependency[0], newer_versions[0]))
                else:
                    raise ValueError(f"Dependency {dependency} can not be"
                                     f"satisfied by any version of "
                                     f"target module")
        _new_graph[mv] = new_deps
    VERSIONED_GRAPH = _new_graph

    # Start building graphs from the leaves:
    def _graphs_from_leaves(
            leaves_stack: List[Module],
            parent_graph: VersionedDigraph
            ) -> Generator[ValidatedGraph, None, None]:
        # Build graphs from the leaves.
        # The graphs will be built from the leaves to the root.
        while leaves_stack:
            leaf_module = leaves_stack.pop()

            # Check if the leaf is already in the graph (in any version)
            if leaf_module in [m for m, _ in parent_graph]:
                # Leaf is already in the graph.
                continue

            versions = unique_modules[leaf_module].copy()
            if leaf_module in newest_wanted:
                versions = filter(_check_version, versions)

            # Sort versions as newest last, so that they are popped first.
            versions = list(sorted(versions))

            for version in versions:
                leaf: VersionedModule = (leaf_module, version)
                subgraph: VersionedDigraph = parent_graph.copy()
                try:
                    leaf_deps_mv = VERSIONED_GRAPH[leaf]
                    leaf_deps_m = GRAPH[leaf_module]
                except KeyError:
                    # Leaf is root
                    leaf_deps_mv = set()
                    leaf_deps_m = set()

                # Check if a conflicting dependency is already in the graph.
                for m, v in subgraph:
                    if m in leaf_deps_m and (m, v) not in leaf_deps_mv:
                        # Graph already contains a different version of
                        # the module that the leaf depends on.
                        break
                else:
                    # No conflicting module found in the graph.
                    subgraph[leaf] = set()
                    if _validate_subgraph(subgraph):
                        # The subgraph is complete.
                        validated_graph = {m: v for m, v in subgraph}
                        print({m: validated_graph[m] for m in newest_wanted})
                        yield validated_graph
                    else:
                    # Continue building the graph from the leaf's dependencies.
                        unfulfilled_deps: Set[Module] = \
                            leaf_deps_m.difference(m for m,_ in subgraph)

                        if not unfulfilled_deps:
                            # Check if other modules in stack need this leaf.
                            for module in leaves_stack:
                                if module == root:
                                    continue
                                if leaf_module in GRAPH[module]:
                                    # Move the module to the front of the stack.
                                    leaves_stack.remove(module)
                                    leaves_stack.append(module)
                                    break
                            else:
                                # Invalid graph. Leaf is not needed.
                                continue

                        next_leaves = leaves_stack + list(unfulfilled_deps)
                        yield from _graphs_from_leaves(
                                next_leaves,
                                subgraph
                            )


    # Build graph from the root:
    def _graphs_from_root(
           add_nodes: List[Module],
           parent_graph: VersionedDigraph
           ) -> Generator[ValidatedGraph, None, None]:
        # Test if the node can be added:
        non_tried_nodes = set(add_nodes)
        while add_nodes and non_tried_nodes:
            add_node = add_nodes.pop()
            non_tried_nodes.remove(add_node)
            if add_node in (m for m, _ in parent_graph):
                # Node is already in the graph.
                continue
            graph = parent_graph.copy()
            for node_version in unique_modules[add_node]:
                node: VersionedModule = add_node, node_version
                node_deps = VERSIONED_GRAPH[node]
                if node_deps and not graph.keys() >= {m for m, _ in node_deps}:
                    # Node has dependencies that are not in the graph.
                    # Move the node to the back of the stack.
                    add_nodes = [add_node] + add_nodes
                    continue
                else:
                    # Node can be added to the graph.
                    graph[node] = set()
                    if _validate_subgraph(graph):
                        # The subgraph is complete.
                        validated_graph = {m: v for m, v in graph}
                        print({m: validated_graph[m] for m in newest_wanted})
                        yield validated_graph
                    else:
                        # Continue building the graph using the node's dependencies.
                        next_nodes = set(
                                m
                                for m, ds
                                in GRAPH
                                if add_node in ds
                            ).difference(m for m, _ in graph)
                        while next_nodes:
                            yield from _graphs_from_root(list(next_nodes), graph)


    # Build graph from missing nodes:
    def _graphs_from_missing(
        missing_node_stack: List[Module],
        parent_graph: VersionedDigraph,
        node_constraints: Dict[Module, Set[Version]]
        ) -> Generator[ValidatedGraph, None, None]:
        # Get all available versions of the missing node -- with version
        # limitations for nodes of interest.
        missing_node = missing_node_stack.pop()
        if missing_node in newest_wanted:
            versions = _get_checked_versions(missing_node)
        else:
            versions = [(missing_node, v) for v in unique_modules[missing_node]]

        if not versions:
            # No versions of the missing node are available.
            return
        else:
            versions = list(sorted(versions))
            node_success = False

            for mv in versions:
                graph = parent_graph.copy()
                try:
                    _add_to_graph(mv, graph, node_constraints)
                    node_success = True
                except ValueError:
                    # Version contains conflicts with another module's
                    # dependency.
                    continue

                # Yield the graph if it is complete or iterate down the stack
                if not missing_node_stack:
                    # The subgraph is complete.
                    import json
                    print(json.dumps(list(graph.keys()), indent=4))

                    validated_graph = {m: v for m, v in graph}
                    print({m: validated_graph[m] for m in newest_wanted})
                    yield validated_graph
                else:
                    graphs= _graphs_from_missing(
                                missing_node_stack,
                                graph,
                                node_constraints)
                    for g in graphs:
                        yield g
                        node_success = True
            # If versions are exhausted, but none of the graphs are go to
            # the next iteration branch.
            if not node_success:
                return

    #valid_graphs = _graphs_from_leaves(list(leaves), {})
    #valid_graphs = _graphs_from_root([root], {})
    version_constraints = {}
    for module in newest_wanted:
        versions = _get_checked_versions(module)
        version_constraints[module] = {v for _, v in versions}
    valid_graphs = _graphs_from_missing(list(unique_modules),
                                        {}, version_constraints)

    def _compare_by_needed(graph: ValidatedGraph) -> Tuple[Version]:
        return tuple(graph[m] for m in newest_wanted) # type: ignore
    newest_graph = max(valid_graphs, key=_compare_by_needed)
    return newest_graph

if __name__ == "__main__":
    with open("graph.csv", "r") as f:
        lines = [line.replace('"', '') for line in f.read().splitlines()]
    import pstats
    import cProfile
    import json
    with cProfile.Profile() as pr:
        try:
            G = _main(lines)
            print(json.dumps(G, indent=4))
        finally:
            stats = pstats.Stats(pr)
            stats.sort_stats(pstats.SortKey.TIME)
            stats.dump_stats("profile.pstats")

