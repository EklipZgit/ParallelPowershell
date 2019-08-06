# Start-Parallel, by James O'Neill! 

# Switch to batching?
function DemoWithStartParallel {
    Param(
        $ThreadCount
    )
    $folderPath = Resolve-Path $PSScriptRoot\TestFiles
    
    $testPath = "$PSScriptRoot\output\StartParallelFiles"
    $null = mkdir $testPath -Force
    $null = Robocopy.exe /MIR $folderPath $testPath
    start-sleep -seconds 1
    
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


$ThreadCount = 1
$time = DemoWithStartParallel -ThreadCount $ThreadCount
Write-Verbose "StartParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 4
$time = DemoWithStartParallel -ThreadCount $ThreadCount
Write-Verbose "StartParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 8
$time = DemoWithStartParallel -ThreadCount $ThreadCount
Write-Verbose "StartParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 16
$time = DemoWithStartParallel -ThreadCount $ThreadCount
Write-Verbose "StartParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 24
$time = DemoWithStartParallel -ThreadCount $ThreadCount
Write-Verbose "StartParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

<# 
Pros: 
    Piping syntax.
    Uses runspaces (and threads), pretty fast.
    No auto-batching into threads, but uses threads pretty efficiently.

Cons:
    No $_ syntax
    No begin / end blocks.
    No using variables.
    Polls the entire list of open tasks every xxx milliseconds, so the more threads you have the more time it wastes checking up on tasks. 
        (Does not scale well to lots of long running low thread workloads). 
        You'll notice the 100 thread ping takes the same as the 50 thread ping, even though it ought to be faster.
        Can't say for sure this is why, but it doesn't seem to scale well.
#>



# What about IO? Lets scan our network for ICMP responses! This would take many, many minutes in a normal foreach loop.

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



