np = 8
nt = 96

pids = addprocs(np)

using SyncObjects

ts = tspace()

#Launch processes on each worker that simulates CPU intensive / blocking stuff for a random amount of time
@everywhere begin
    function simworker(ts)
        if iseven(myid())
            key = string(myid())
        else
            key = r".*"
        end
#        key = r".*"
        
        while true
            r = take!(ts, key)
            lsecs = rand()
#            lsecs = 1.0
            t1 = time()
            while (time() - t1) < lsecs
                # empty loop simulating CPU intensive code
            end
            
            put!(r[2], "Finished $(r[1]) in $lsecs seconds @ worker $(myid())")
        end
    end
end

for p in pids
    @spawnat p simworker(ts)
end

# Start n tasks concurrently - each adding its request to ts and waiting for a result
tic()
@sync begin
    for i in 1:nt
        @async begin
            rr = RemoteRef()
            put!(ts, ("$((i%(np))+2)", rr))
            result = take!(rr)
#             println(result)
#             println("jobs left to be taken : $(length(ts))")
        end
    end
end
toc()