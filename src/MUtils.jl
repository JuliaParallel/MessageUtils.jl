module MUtils

import Base.fetch, Base.put!, Base.take!, Base.isready, Base.wait

include("core.jl")
include("spaces.jl")
include("ctasks.jl")

type DNSHandle
    h::SyncObjRef
    DNSHandle() = new() 
end

const dns = DNSHandle()

# Globally available dictionary
function dnsref()
    if !isdefined (dns, :h)
        if (myid() == 1)
            dns.h = kvspace(;sz=-1)
        else
            dns.h = remotecall_fetch(1, ()->MUtils.dnsref()) 
        end
    end
    return dns.h
end


end