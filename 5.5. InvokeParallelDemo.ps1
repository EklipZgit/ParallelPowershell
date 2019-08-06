# Invoke-Parallel, by RamblingCookieMonster!

# Wtf, having to dotsource .ps1's? :(
. .\Invoke-Parallel.ps1

# Switch to batching?
function DemoWithInvokeParallel {
    Param(
        $ThreadCount
    )
    $folderPath = Resolve-Path $PSScriptRoot\TestFiles
    
    $testPath = "$PSScriptRoot\output\InvokeParallelFiles"
    $null = mkdir $testPath -Force
    $null = Robocopy.exe /MIR $folderPath $testPath
    start-sleep -seconds 1
    
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


$ThreadCount = 1
$time = DemoWithInvokeParallel -ThreadCount $ThreadCount
Write-Verbose "InvokeParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 4
$time = DemoWithInvokeParallel -ThreadCount $ThreadCount
Write-Verbose "InvokeParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

$ThreadCount = 8
$time = DemoWithInvokeParallel -ThreadCount $ThreadCount
Write-Verbose "InvokeParallel files Used $time seconds with $ThreadCount thread count!" -Verbose

<# 
Pros: 
    Piping syntax.
    Uses runspaces (and threads), pretty fast.

Cons:
    No $_ syntax
    No using variables.
    Polls the entire list of open tasks every xxx milliseconds, so the more threads you have the more time it wastes checking up on tasks. 
        (Does not scale well to lots of long running low CPU workloads)
#>



# What about IO? Lets scan our network for ICMP responses! This would take many, many minutes in a normal foreach loop.

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



