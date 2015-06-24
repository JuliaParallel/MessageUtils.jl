export channel, tspace, kvspace
export RemoteChannel, RemoteKVSpace, RemoteTSpace
import Base.length

type ValStore
    v
    expire::Float64     
end

type RemoteChannel <: AbstractRemoteSyncObj
    # type specific fields
    space::Vector{ValStore}
    sz
    vtype::Type
    
    # AbstractRemoteSyncObj required fields
    so::SyncObjData
    cantake::Function
    canput::Function
    fetch::Function
    put::Function
    take::Function
    query::Function
    
    # Housekeeping stuff
    t::Timer

    function RemoteChannel(T, sz) 
        rc = new(Array(ValStore, 0), sz, T, SyncObjData(), rccantake, rccanput, rcfetch, rcput, rctake, rcquery)
        rc.t = hk_timer(rc)
        finalizer(rc, rso_cleanup)
        rc
    end
end

type RemoteKVSpace <: AbstractRemoteSyncObj
    space::Dict{Any, ValStore}
    sz
    so::SyncObjData
    cantake::Function
    canput::Function
    fetch::Function
    put::Function
    take::Function
    query::Function
    t::Timer

    function RemoteKVSpace(sz) 
        kvs = new(Dict{Any, ValStore}(), sz, SyncObjData(), kvscantake, kvscanput, kvsfetch, kvsput, kvstake, kvsquery)
        kvs.t = hk_timer(kvs)
        finalizer(kvs, rso_cleanup)
        kvs
    end
end

type RemoteTSpace <: AbstractRemoteSyncObj
    space::Vector{ValStore}
    sz
    so::SyncObjData
    cantake::Function
    canput::Function
    fetch::Function
    put::Function
    take::Function
    query::Function
    t::Timer

    function RemoteTSpace(sz) 
        ts = new(Array(ValStore, 0), sz, SyncObjData(), tscantake, tscanput, tsfetch, tsput, tstake, tsquery)
        ts.t = hk_timer(ts)
        finalizer(ts, rso_cleanup)
        ts
    end
end

typealias SyncObjectTypes Union(RemoteChannel, RemoteKVSpace, RemoteTSpace)

function hk_timer(rso::SyncObjectTypes)
    if isv4
        t = Timer(t -> housekeeping(rso), 15.0, 15.0)
    else
        t = Timer(t -> housekeeping(rso))
        start_timer(t, 15.0, 15.0)
    end
    t
end

function housekeeping(ts::Union(RemoteChannel, RemoteTSpace))
    try 
        tnow = time()
        filter!(x -> (tnow < x.expire), ts.space)
    catch
        warn("Error in housekeeping function")
    end
end

function housekeeping(ts::RemoteKVSpace)
#    println("Timer called for type ", typeof(ts), " oid ", object_id(ts))
    try 
        tnow = time()
        dlist = Array(Any, 0)
        for (k, v) in ts.space
            if v.expire < tnow
                push!(dlist, k)
            end
        end
        
        for k in dlist
            delete!(ts.space, k)
        end
    catch
        warn("Error in housekeeping function")
    end
end

function rso_cleanup(rso::SyncObjectTypes)
    if isv4
        close(rso.t)
    else
        stop_timer(rso.t)   # Otherwise, it won't get gc'ed!
    end
end

rccantake(rv::RemoteChannel) = (length(rv.space) > 0)
rccanput(rv::RemoteChannel, args...) = (rv.sz < 0) || (length(rv.space) < rv.sz)

kvscantake(rv::RemoteKVSpace, key) = haskey(rv.space, key)
kvscanput(rv::RemoteKVSpace, args...) = (rv.sz < 0) || (length(rv.space) < rv.sz)

tscantake(rv::RemoteTSpace, key) = key in [x.v[1] for x in rv.space]
function tscantake(rv::RemoteTSpace, r::Regex)
    for x in rv.space
        k = x.v[1]
        if testmatch(r, k)
            return true
        end
    end
    return false
end

testmatch(r::Any, k) = (r == k)
testmatch(r::Regex, k) = false
testmatch(r::Regex, k::String) = ismatch(r, k)

tscanput(rv::RemoteTSpace, args...) = (rv.sz < 0) || (length(rv.space) < rv.sz)

function expire_at(kw) 
    for (k,v) in kw
        if (k == :expire) && (v > 0.0)
            return time() + v
        end
    end
    return time() + 3.15569e9   # 100 years from now
end

function rcput(rv::RemoteChannel, val; kw...) 
    if !isa(val, rv.vtype) 
        error("This channel only supports values of type " * string(rv.vtype))
    end
    push!(rv.space, ValStore(val, expire_at(kw)))
end

kvsput(rv::RemoteKVSpace, key, val; kw...) = (rv.space[key] = ValStore(val, expire_at(kw)))
tsput(rv::RemoteTSpace, val::Tuple; kw...) = push!(rv.space, ValStore(val, expire_at(kw)))

rctake(rv::RemoteChannel; kw...) = (vs = shift!(rv.space); vs.v)
kvstake(rv::RemoteKVSpace, key; kw...) = (vs = rv.space[key]; delete!(rv.space, key); vs.v)
function tstake(rv::RemoteTSpace, key; kw...) 
    idx = findfirst(x->testmatch(key,x), Any[t.v[1] for t in rv.space])
    vs=splice!(rv.space, idx)
    vs.v
end


rcfetch(rv::RemoteChannel; kw...) = rv.space[1].v
kvsfetch(rv::RemoteKVSpace, key; kw...) = rv.space[key].v 
kvsfetch(rv::RemoteKVSpace; kw...) = nothing
function tsfetch(rv::RemoteTSpace, key; kw...) 
    idx = findfirst(x->testmatch(key,x), Any[t.v[1] for t in rv.space])
    rv.space[idx].v
end
tsfetch(rv::RemoteTSpace; kw...) = nothing

rcquery(rv::RemoteChannel, args...) = length(rv.space)
kvsquery(rv::RemoteKVSpace, args...) = length(rv.space)
tsquery(rv::RemoteTSpace, args...) = length(rv.space)

length(rr::SyncObjRef) = query(rr)



# Exports
tspace(pid=myid(); sz=1000) = syncobj_create(pid, MessageUtils.RemoteTSpace, sz)
kvspace(pid=myid(); sz=1000) = syncobj_create(pid, MessageUtils.RemoteKVSpace, sz)
channel(pid=myid(); T=Any, sz=1000) = syncobj_create(pid, MessageUtils.RemoteChannel, T, sz)


