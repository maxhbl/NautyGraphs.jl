mutable struct NautyOptions
    getcanon::Cint
    digraph::Cbool
    writeautoms::Cbool
    writemarkers::Cbool
    defaultptn::Cbool
    cartesian::Cbool
    linelength::Cint

    outfile::Ptr{Cvoid}
    userrefproc::Ptr{Cvoid}
    userautomproc::Ptr{Cvoid}
    userlevelproc::Ptr{Cvoid}
    usernodeproc::Ptr{Cvoid}
    usercanonproc::Ptr{Cvoid}
    invarproc::Ptr{Cvoid}

    tc_level::Cint
    mininvarlevel::Cint
    maxinvarlevel::Cint
    invararg::Cint

    dispatch::Ptr{Cvoid}

    schreier::Cbool
    extra_options::Ptr{Cvoid}

    NautyOptions() = new(
        0, false, false, false, true, false, 78,
        C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL,
        100, 0, 1, 0,
        C_NULL,
        false, C_NULL
    )
end
mutable struct NautyStatistics
    grpsize1::Cdouble
    grpsize2::Cint
    numorbits::Cint
    numgenerators::Cint
    errstatus::Cint
    numnodes::Culong
    numbadleaves::Culong
    maxlevel::Cint
    tctotal::Culong
    canupdates::Culong
    invapplics::Culong
    invsuccesses::Culong
    invarsuclevel::Cint

    NautyStatistics() = new(
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
end

# TODO: Make this useful
# struct AutomorphismGroup{T<:Integer}
#     n::T
#     orbits::Vector{T}
#     generators::T
#     # ... 
# end

function nauty(::Type{T}, g::DenseNautyGraph, canonical_form=true; ignore_vertex_labels=false, kwargs...) where {T} #TODO: allow nautyoptions to be overwritten
    n, m = g.n_vertices, g.n_words

    options = NautyOptions()
    options.getcanon = canonical_form
    options.digraph = is_directed(g)
    options.defaultptn = all(iszero, g.labels) || ignore_vertex_labels #TODO: check more carefully if lab/ptn is valid
    lab, ptn = _vertexlabels_to_labptn(g.labels)

    stats = NautyStatistics()

    orbits = zeros(Cint, n)
    h = zero(g.graphset)

    @ccall nauty_lib.densenauty_wrap(
        g.graphset::Ref{Cuint},
        lab::Ref{Cint},
        ptn::Ref{Cint},
        orbits::Ref{Cint},
        Ref(options)::Ref{NautyOptions},
        Ref(stats)::Ref{NautyStatistics},
        m::Cint,
        n::Cint,
        h::Ref{Cuint})::Cvoid

    grpsize = T(stats.grpsize1 * 10^stats.grpsize2)
    # autmorph = AutomorphismGroup{T}(grpsize, orbits, stats.numgenerators) # TODO: summarize useful automorphism group info

    if canonical_form
        canong = h
        canon_perm = lab .+ 1
    else
        canong = nothing
        canon_perm = nothing
    end
    return grpsize, canong, canon_perm
end
nauty(g::DenseNautyGraph, canonical_form=true; kwargs...) = nauty(Int, g, canonical_form; kwargs...)

function _fill_hash!(g::AbstractNautyGraph)
    n, canong, canon_perm = nauty(g, true)
    topology_hash = hash(canong)
    hashval = hash(g.labels[canon_perm], topology_hash)
    g.hashval = hashval
    return hashval, n
end

function canonize!(g::AbstractNautyGraph)
    n, canong, canon_perm = nauty(g, true)
    topology_hash = hash(canong)

    g.graphset .= canong
    g.labels .= g.labels[canon_perm]
    g.hashval = hash(g.labels, topology_hash)

    return canon_perm, n
end

function Base.hash(g::AbstractNautyGraph)
    hashval = g.hashval
    if !isnothing(hashval)
        return hashval
    end

    # TODO: error checking and so on
    _fill_hash!(g)
    return g.hashval
end

is_isomorphic(g::AbstractNautyGraph, h::AbstractNautyGraph) = hash(g) == hash(h)
≃(g::AbstractNautyGraph, h::AbstractNautyGraph) = is_isomorphic(g, h)