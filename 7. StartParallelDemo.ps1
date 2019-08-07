# Start-Parallel, by James O'Neill! 

. $PSScriptRoot\helpers\PrepFiles.ps1

if (-not (Get-Module 'Start-Parallel' -ListAvailable))
{
    Install-Module 'Start-Parallel' -Force
}

# We'll try unbatched since it supports piping and thread throttling!
function DemoWithStartParallelUnbatched {
    Param(
        $ThreadCount
    )

    $testPath = PrepFiles $PSScriptRoot 'StartParallelUnbatched'
    
    $start = Get-Date
    $allFiles = Get-ChildItem -Path $testPath    
    $allFiles | Select-Object -ExpandProperty FullName | Start-Parallel -Scriptblock {
        PARAM ($filePath) 
        $content = Get-Content -Path $filePath -Raw
        $content = $content -replace "dolor", "REPLACED-1!"
        $content = $content -replace "elit", "REPLACED-2!"
        $content | Set-Content -Path $filePath -Encoding UTF8
    } -MaxThreads $ThreadCount -MilliSecondsDelay 100

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$ThreadCount = 2
$time = DemoWithStartParallelUnbatched -ThreadCount $ThreadCount
Write-Verbose "StartParallel unbatched files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 8
$time = DemoWithStartParallelUnbatched -ThreadCount $ThreadCount
Write-Verbose "StartParallel unbatched files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 16
$time = DemoWithStartParallelUnbatched -ThreadCount $ThreadCount
Write-Verbose "StartParallel unbatched files Used $time seconds with $ThreadCount thread count!" -Verbose



# Batches, similar to how we did Start-Job, ThreadJob, and RSJob
function DemoWithStartParallelBatched {
    Param(
        $BatchCount
    )
    $testPath = PrepFiles $PSScriptRoot 'StartParallelBatched'
    
    # Again, if we go through the effort of manually batching, we get much better performance. A frustrating thing to need to do...
    # At least with its input syntax batching looks a little bit cleaner, even though the parameter mapping is magic...
    $allFiles = Get-ChildItem -Path $testPath
    $numFiles = $allFiles.Count
    $numPerJob = $numFiles / $BatchCount

    $start = Get-Date
    # Kind of confusing but cool parameter syntax...
    $batches = foreach ($i in 0..($BatchCount - 1))
    {
        [PSCustomObject]@{ 'files' = ($allFiles | Select-Object -skip ($i * $numPerJob) -first $numPerJob) }
    }
    # Each of these custom objects properties get splatted to the parameter names in your scriptblock. Unconventional, but pretty cool.
    $batches | Start-Parallel -Scriptblock {
        PARAM ($files) 
        foreach ($file in $files)
        {
            $content = Get-Content -Path $file.FullName -Raw
            $content = $content -replace "dolor", "REPLACED-1!"
            $content = $content -replace "elit", "REPLACED-2!"
            $content | Set-Content -Path $file.FullName -Encoding UTF8
        }
    } -MaxThreads $BatchCount -MilliSecondsDelay 100

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$BatchCount = 2
$time = DemoWithStartParallelBatched -BatchCount $BatchCount
Write-Verbose "StartParallel BATCHED files Used $time seconds with $BatchCount BatchCount count!" -Verbose

$BatchCount = 8
$time = DemoWithStartParallelBatched -BatchCount $BatchCount
Write-Verbose "StartParallel BATCHED files Used $time seconds with $BatchCount BatchCount count!" -Verbose

$BatchCount = 16
$time = DemoWithStartParallelBatched -BatchCount $BatchCount
Write-Verbose "StartParallel BATCHED files Used $time seconds with $BatchCount BatchCount count!" -Verbose

<# 
Pros: 
    Piping syntax. (But creates a thread per object, so you have to batch or accept performance loss).
    Uses runspaces (and threads), pretty fast.
    No auto-batching into threads, but uses threads pretty efficiently.
    No managing of jobs yourself, so good for parallel-loop type tasks.

Cons:
    No $_ syntax
    No begin / end blocks.
    No using variables.
    Polls the entire list of open tasks every xxx milliseconds, so the more threads you have the more time it wastes checking up on tasks. 
        (Does not scale well to lots of long running low thread workloads). 
        You'll notice the 100 thread ping takes the same as the 50 thread ping, even though it ought to be faster.
        Can't say for sure this is why, but it doesn't seem to scale well.
#>



# Lets try our Test-NetConnection ICMP pings with Start-Parallel!

$ips = 0..100

function DemoTNCWithStartParallel {
    Param(
        $ThreadCount,
        $IPs
    )
    $start = Get-Date
    $fullIps = foreach ($ipEnd in $ips)
    {
        "192.168.0.$ipEnd"
    }
    
    $results = $fullIps | Start-Parallel -Scriptblock {
        PARAM ($ip) 
        $result = Test-NetConnection -ComputerName $ip -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Output ([PSCustomObject]@{IP = $ip; Result = $result})
    } -MaxThreads $ThreadCount -MilliSecondsDelay 300

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$ThreadCount = 20
$time = DemoTNCWithStartParallel -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "StartParallel TNC Used $time seconds with $ThreadCount thread count!" -Verbose


$ThreadCount = 50
$time = DemoTNCWithStartParallel -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "StartParallel TNC Used $time seconds with $ThreadCount thread count!" -Verbose


$ThreadCount = 100
$time = DemoTNCWithStartParallel -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "StartParallel TNC Used $time seconds with $ThreadCount thread count!" -Verbose

# Note that while almost all of the other solutions were still faster for 100 Test-NetConnections with 100 threads, this one is significantly slower than 50 threads...

# In the end, the syntax is kind of cool for parameterized stuff, but the module does not perform well. :(

