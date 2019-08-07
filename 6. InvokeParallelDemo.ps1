# Invoke-Parallel, by RamblingCookieMonster!

. $PSScriptRoot\helpers\PrepFiles.ps1

# Not available on the PSGallery :(
. $PSScriptRoot\helpers\Invoke-Parallel.ps1

function DemoWithInvokeParallelUnbatched {
    Param(
        $ThreadCount
    )
    $testPath = PrepFiles $PSScriptRoot 'InvokeParallelUnbatched'
    
    $start = Get-Date
    $allFiles = Get-ChildItem -Path $testPath
    $allFiles | Select-Object -ExpandProperty FullName | Invoke-Parallel -Scriptblock {
        $content = Get-Content -Path $_ -Raw
        $content = $content -replace "dolor", "REPLACED-1!"
        $content = $content -replace "elit", "REPLACED-2!"
        $content | Set-Content -Path $_ -Encoding UTF8
    } -Throttle $ThreadCount

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}



$ThreadCount = 4
$time = DemoWithInvokeParallelUnbatched -ThreadCount $ThreadCount
Write-Verbose "InvokeParallel unbatched files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 8
$time = DemoWithInvokeParallelUnbatched -ThreadCount $ThreadCount
Write-Verbose "InvokeParallel unbatched files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 16
$time = DemoWithInvokeParallelUnbatched -ThreadCount $ThreadCount
Write-Verbose "InvokeParallel unbatched files Used $time seconds with $ThreadCount thread count!" -Verbose



# Batches, similar to how we did Start-Job, ThreadJob, and RSJob
function DemoWithInvokeParallelBatched {
    Param(
        $BatchCount
    )
    $testPath = PrepFiles $PSScriptRoot 'InvokeParallelBatched'
    
    # Again, if we go through the effort of manually batching, we get much better performance. A frustrating thing to need to do...
    $allFiles = Get-ChildItem -Path $testPath
    $numFiles = $allFiles.Count
    $numPerJob = $numFiles / $BatchCount

    $start = Get-Date
    $batches = foreach ($i in 0..($BatchCount - 1))
    {
        [PSCustomObject]@{ 'files' = ($allFiles | Select-Object -skip ($i * $numPerJob) -first $numPerJob) }
    }    
    $batches | Invoke-Parallel -Scriptblock {
        foreach ($file in $_.files)
        {
            $content = Get-Content -Path $file.FullName -Raw
            $content = $content -replace "dolor", "REPLACED-1!"
            $content = $content -replace "elit", "REPLACED-2!"
            $content | Set-Content -Path $file.FullName -Encoding UTF8
        }
    } -Throttle $BatchCount

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$BatchCount = 4
$time = DemoWithInvokeParallelBatched -BatchCount $BatchCount
Write-Verbose "InvokeParallel BATCHED files Used $time seconds with $BatchCount thread count!" -Verbose

$BatchCount = 8
$time = DemoWithInvokeParallelBatched -BatchCount $BatchCount
Write-Verbose "InvokeParallel BATCHED files Used $time seconds with $BatchCount thread count!" -Verbose

$BatchCount = 16
$time = DemoWithInvokeParallelBatched -BatchCount $BatchCount
Write-Verbose "InvokeParallel BATCHED files Used $time seconds with $BatchCount thread count!" -Verbose

<# 
Pros: 
    Piping syntax.
    Uses runspaces (and threads), pretty fast.
    No managing of jobs yourself, so good for parallel-loop type tasks.

Cons:
    No $_ syntax
    No using variables.
    Polls the entire list of open tasks every xxx milliseconds, so the more threads you have the more time it wastes checking up on tasks. 
        (Does not scale well to lots of long running low CPU workloads)
    One or more errors occurred randomly? No idea what that is about, doesn't give any more information when it happens.
    Same module load inconsistency issue as PoshRsJob:
        Get-RunspaceData : The 'Test-NetConnection' command was found in the module 'NetTCPIP', but the module could not be loaded. For more information, run 
            'Import-Module NetTCPIP'.
        (This may be a problem in ThreadJob and SplitPipeline as well for all I know, it is uncommon and difficult to reproduce consistently)
#>



# Lets try our Test-NetConnection ICMP pings with Invoke-Parallel!

$ips = 0..100

function DemoTNCWithInvokeParallel {
    Param(
        $ThreadCount,
        $IPs
    )
    $start = Get-Date
    $fullIps = foreach ($ipEnd in $ips)
    {
        "192.168.0.$ipEnd"
    }
    
    $results = $fullIps | Invoke-Parallel -Scriptblock {
        $result = Test-NetConnection -ComputerName $_ -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Output ([PSCustomObject]@{IP = $_; Result = $result})
    } -Throttle $ThreadCount
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$ThreadCount = 20
$time = DemoTNCWithInvokeParallel -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "InvokeParallel TNC Used $time seconds with $ThreadCount thread count!" -Verbose


$ThreadCount = 50
$time = DemoTNCWithInvokeParallel -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "InvokeParallel TNC Used $time seconds with $ThreadCount thread count!" -Verbose


$ThreadCount = 100
$time = DemoTNCWithInvokeParallel -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "InvokeParallel TNC Used $time seconds with $ThreadCount thread count!" -Verbose



