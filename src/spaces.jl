export channel, tspace, kvspace


type RemoteChannel <: AbstractRemoteSyncObj
    q::Vector
    sz
    so::SyncObjData
    test_cantake::Function
    test_canput::Function
    fetch::Function
    put::Function
    take::Function

    RemoteChannel(T, sz) = new(Array(T, 0), sz, SyncObjData(), rccantake, rccanput, rcfetch, rcput, rctake)
end

type RemoteKVSpace <: AbstractRemoteSyncObj
    space::Dict
    sz
    so::SyncObjData
    test_cantake::Function
    test_canput::Function
    fetch::Function
    put::Function
    take::Function

    RemoteKVSpace(sz) = new(Dict(), sz, SyncObjData(), kvscantake, kvscanput, kvsfetch, kvsput, kvstake)
end

type RemoteTSpace <: AbstractRemoteSyncObj
    space::Vector{Tuple}
    sz
    so::SyncObjData
    test_cantake::Function
    test_canput::Function
    fetch::Function
    put::Function
    take::Function

    RemoteTSpace(sz) = new(Array(Tuple, 0), sz, SyncObjData(), tscantake, tscanput, tsfetch, tsput, tstake)
end



rccantake(rv::RemoteChannel) = (length(rv.q) > 0)
rccanput(rv::RemoteChannel, args...) = (length(rv.q) < rv.sz)

kvscantake(rv::RemoteKVSpace, key) = haskey(rv.space, key)
kvscanput(rv::RemoteKVSpace, args...) = (length(rv.space) < rv.sz)

tscantake(rv::RemoteTSpace, key) = key in [x[1] for x in rv.space]
function tscantake(rv::RemoteTSpace, r::Regex)
    for x in rv.space
        k = x[1]
        if testmatch(r, k)
            return true
        end
    end
    return false
end
testmatch(r::Regex, k) = false
testmatch(r::Regex, k::String) = ismatch(r, k)

tscanput(rv::RemoteTSpace, args...) = (length(rv.space) < rv.sz)

rcput(rv::RemoteChannel, val) = push!(rv.q, val)
kvsput(rv::RemoteKVSpace, key, val) = (rv.space[key] = val)
tsput(rv::RemoteTSpace, val::Tuple) = push!(rv.space, val)

rctake(rv::RemoteChannel) = shift!(rv.q)
kvstake(rv::RemoteKVSpace, key) = (val = rv.space[key]; delete!(rv.space, key); val)
tstake(rv::RemoteTSpace, key) = (idx = findfirst(x->x==key, {t[1] for t in rv.space}); splice!(rv.space, idx))
tstake(rv::RemoteTSpace, r::Regex) = (idx = findfirst(x->testmatch(r,x), {t[1] for t in rv.space}); splice!(rv.space, idx))


rcfetch(rv::RemoteChannel) = rv.q[1]
kvsfetch(rv::RemoteKVSpace, key) = rv.space[key] 
kvsfetch(rv::RemoteKVSpace) = nothing
tsfetch(rv::RemoteTSpace, key) = (idx = findfirst(x->x==key, {t[1] for t in rv.space}); rv.space[idx])
tsfetch(rv::RemoteTSpace, r::Regex) = (idx = findfirst(x->testmatch(r,x), {t[1] for t in rv.space}); rv.space[idx])
tsfetch(rv::RemoteTSpace) = nothing


# Exports
tspace(pid=myid(); sz=1000) = syncobj_create(pid, SyncObjects.RemoteTSpace, sz)
kvspace(pid=myid(); sz=1000) = syncobj_create(pid, SyncObjects.RemoteKVSpace, sz)
channel(pid=myid(); T=Any, sz=1000) = syncobj_create(pid, SyncObjects.RemoteChannel, T, sz)


