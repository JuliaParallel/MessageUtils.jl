import Base.start, Base.done, Base.next, Base.put!, Base.take!
export ctask

type CTask
    name::String
    inq::SyncObjRef
    outq::SyncObjRef
    rr::RemoteRef               # Holds the task
    CTask(name) = new(name, channel(), channel(), RemoteRef())
end

register_ct(name::String, ct::CTask) = put!(MessageUtils.dnsref(), (:ctask, name), ct)
deregister_ct(name::String) = take!(MessageUtils.dnsref(), (:ctask, name))
fetch_ct(name::String; timeout=0.001) = fetch(MessageUtils.dnsref(), (:ctask, name); timeout=timeout)

# Should only be executed on the node where the task is expected to be started
function ctwrap(ct, f)
    task_local_storage(:CTASK, ct)
    try
        f()

    finally
        if (ct.name != "")
             deregister_ct(ct.name)   # Handle error condition where entry is not found
        end
    end
    nothing
end


function ctask_start(f, name)
    ct = CTask(name)
    if (name != "")
        register_ct(name, ct)
    end
    t=Task(()->ctwrap(ct,f))
    put!(ct.rr, t)
    schedule(t)
    ct
end



function ctask(f::Function; pid=myid(), name="")
    if pid == myid()
        ctask_start(f, name)
    else
        remotecall_fetch(pid, () -> ctask_start(f, name))
    end
end

start(ct::CTask) = nothing
done(ct::CTask, state) = false
next(ct::CTask, state) = take!(ct.inq)

ctask_self() = task_local_storage(:CTASK)

# Sending a message to a task
(|>)(msg::Tuple, ctname::String) = put!(ctname, msg)
(|>)(msg::Tuple, ct::CTask) = put!(ct, msg)

put!(msg::Tuple; timeout=0.0) = (put!(ctask_self().outq, msg; timeout=timeout); nothing)
put!(ct::CTask, msg::Tuple; timeout=0.0) = (put!(ct.inq, msg; timeout=timeout); nothing)
put!(ctname::String, msg::Tuple; timeout=0.0) = put!(fetch_ct(ctname), msg; timeout=timeout)


# Pulling a message from a task
take!(; timeout=0.0) = take!(ctask_self().inq; timeout=timeout)
take!(ct::CTask; timeout=0.0) = take!(ct.outq; timeout=timeout)
take!(ctname::String; timeout=0.0) = take!(fetch_ct(ctname); timeout=timeout)

