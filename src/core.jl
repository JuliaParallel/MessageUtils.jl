type MUtilTimeOutEx <: Exception
end

type SyncObjRef{T}
    rr::RemoteRef
    SyncObjRef() = new(RemoteRef())
end

function call_on_owner(f, h::SyncObjRef, args...; kw...)
    if h.rr.where == myid()
        f(h, args...; kw...)
    else
        remotecall_fetch(h.rr.where, () -> f(h, args...; kw...))
    end
end

# Just a wrapper for a RemoteRef - so that we can support our own
# methods similar to that supported for RemoteRefs 

type SyncObjData
    cantake::Condition   # waiting for a value
    canput::Condition  # waiting for value to be removed

    SyncObjData() = new (Condition(), Condition())
end

# data stored by the owner of a RemoteRef
abstract AbstractRemoteSyncObj

function syncobj(T::Type, args...; kw...) 
    h = SyncObjRef{T}()
    put!(h.rr, T(args...; kw...))
    h
end


function syncobj_create(pid, T, args...; kw...) 
    remotecall_fetch(pid, ()->syncobj(T, args...; kw...))
end


function setup_waittimer(condvar, timeout)
    t1 = time()
    if isv4
        t = Timer(x -> notify(condvar), timeout, 0.0)
    else
        t = Timer(x -> notify(condvar))
        start_timer(t, timeout, 0.0)
    end
    (t1, t)
end

function kwextract(kw, fld, default) 
    for (k,v) in kw
        if (k == fld)
            return v
        end
    end
    return default
end

function wait_cantake (rv::AbstractRemoteSyncObj, args...; kw...)
    timeout = kwextract(kw, :timeout, 0.0)
    (t1, t) = (timeout > 0.0) ? setup_waittimer(rv.so.cantake, timeout) : (0, nothing)

    try
        while !rv.cantake(rv, args...)
            # Multiple tasks are waiting on the same condition variable.
            # Consequently, we may get woken up but not find any data for ourselves.
            (timeout > 0.0) && ((time() - t1) > timeout) && throw(MUtilTimeOutEx())
            wait( rv.so.cantake )
        end
    finally
        if isv4
            (t != nothing) && close(t)
        else
            (t != nothing) && stop_timer(t)
        end
    end
    return ( rv.fetch(rv, args...) )
end


function wait_canput(rv::AbstractRemoteSyncObj, args...; kw...)
    timeout = kwextract(kw, :timeout, 0.0)
    (t1, t) = (timeout > 0.0) ? setup_waittimer(rv.so.canput, timeout) : (0, nothing)
    
    try
        while !rv.canput(rv, args...)
            (timeout > 0.0) && ((time() - t1) > timeout) && throw(MUtilTimeOutEx())
            wait(rv.so.canput)
        end
    finally
        if isv4
            (t != nothing) && close(t)
        else
            (t != nothing) && stop_timer(t)
        end
    end
    return nothing
end


wait_ref(h, args...; kw...) = (wait_cantake(fetch(h.rr), args...; kw...); nothing)
wait(h::SyncObjRef, args...; kw...) = (call_on_owner(wait_ref, h, args...; kw...); h)

fetch_ref(h, args...; kw...) = wait_cantake(fetch(h.rr), args...; kw...)
fetch(h::SyncObjRef, args...; kw...) = call_on_owner(fetch_ref, h, args...; kw...)

# storing a value to a Ref
function put!(rv::AbstractRemoteSyncObj, args...; kw...)
    wait_canput(rv, args...; kw...)
    rv.put(rv, args...; kw...)
    notify(rv.so.cantake, rv.fetch(rv))
end


put_ref(h, args...; kw...) = put!(fetch(h.rr), args...; kw...)
put!(h::SyncObjRef, args...; kw...) = (call_on_owner(put_ref, h, args...; kw...); h)

function take!(rv::AbstractRemoteSyncObj, args...; kw...)
    wait_cantake(rv, args...; kw...)
    val = rv.take(rv, args...)
    notify(rv.so.canput)
    val
end


take_ref(h; kw...) = take!(fetch(h.rr); kw...)
take_ref(h, key; kw...) = take!(fetch(h.rr), key; kw...)
take!(h::SyncObjRef; kw...) = call_on_owner(take_ref, h; kw...)
take!(h::SyncObjRef, key; kw...) = call_on_owner(take_ref, h, key; kw...)

query_ref(h, args...) = query(fetch(h.rr), args...)
query(h::SyncObjRef, args...) = call_on_owner(query_ref, h, args...)
query(rv::AbstractRemoteSyncObj, args...) = rv.query(rv, args...)

function isready(h::SyncObjRef, args...)
    remotecall_fetch(h.rr.where, (rr, rargs...) -> begin rv = fetch(rr); rv.cantake(rv, rargs...) end, h.rr, args...)
end


