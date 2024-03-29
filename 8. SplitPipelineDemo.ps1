# Split-Pipeline, by nightroman!

# Is there a better way than managing all the jobs these previous modules used??? Perhaps!

. $PSScriptRoot\helpers\PrepFiles.ps1

if (-not (Get-Module 'SplitPipeline' -ListAvailable))
{
    Install-Module 'SplitPipeline' -Force
}

function DemoWithSplitPipeline {
    Param(
        $ThreadCount
    )
    $testPath = PrepFiles $PSScriptRoot 'SplitPipeline'
    
    $allFiles = Get-ChildItem -Path $testPath
    
    $start = Get-Date
    # Fast AND automatic batching? No way! Way less boilerplate code other than the extra process {} block.
    $allFiles | Split-Pipeline -Count $ThreadCount -Script { process {
        $content = Get-Content -Path $_.FullName -Raw
        $content = $content -replace "dolor", "REPLACED-1!"
        $content = $content -replace "elit", "REPLACED-2!"
        $content | Set-Content -Path $_.FullName -Encoding UTF8
    } }

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$ThreadCount = 2
$time = DemoWithSplitPipeline -ThreadCount $ThreadCount
Write-Verbose "SplitPipeline files Used $time seconds with $ThreadCount Thread count!" -Verbose

$ThreadCount = 4
$time = DemoWithSplitPipeline -ThreadCount $ThreadCount
Write-Verbose "SplitPipeline files Used $time seconds with $ThreadCount Thread count!" -Verbose

$ThreadCount = 8
$time = DemoWithSplitPipeline -ThreadCount $ThreadCount
Write-Verbose "SplitPipeline files Used $time seconds with $ThreadCount Thread count!" -Verbose

$ThreadCount = 16
$time = DemoWithSplitPipeline -ThreadCount $ThreadCount
Write-Verbose "SplitPipeline files Used $time seconds with $ThreadCount Thread count!" -Verbose

$ThreadCount = 24
$time = DemoWithSplitPipeline -ThreadCount $ThreadCount
Write-Verbose "SplitPipeline files Used $time seconds with $ThreadCount Thread count!" -Verbose
<# 
Pros: 
    Allows begin and end blocks (so if you have some setup that must 
        be run once per process, like importing modules, you can use that)
    Very fast compared to Start-Job.
    Very pleasant to use. $_ syntax is very nice. Notice how much less code this took to set up properly than start-job did.
    No need to worry about batching to make optimal use of your CPUs / threads (like we had to for RSJob / Start-Job).
    No managing of jobs yourself, so good for parallel-loop type tasks.

Cons:
    Not the most performant when hyper-tuning. I was able to hyper-tune better performance from RSJob 
        (and I believe ThreadJob is now more performant than RSJobs?).
        Out of the box without trying to hyper-tune for specific cases, 
        this is by far the easiest to get great performance from.
        No tweaking batch size madness, it just works.
    Requires the process block in -ScriptBlock { process { } } syntax. 
    Output streams could be handled better, more on that in 9.)
#>



# Lets try our Test-NetConnection ICMP pings with Split-Pipeline!

$ips = 0..100

function DemoTNCWithSplitPipeline {
    Param(
        $ThreadCount,
        $IPs
    )
    $start = Get-Date
    $fullIps = foreach ($ipEnd in $ips)
    {
        "192.168.0.$ipEnd"
    }
    
    $results = $fullIps | Split-Pipeline -Count $ThreadCount -Script { process {
        $result = Test-NetConnection -ComputerName $_ -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Output ([PSCustomObject]@{IP = $_; Result = $result})
    } }

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$ThreadCount = 20
$time = DemoTNCWithSplitPipeline -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "SplitPipeline TNC Used $time seconds with $ThreadCount Thread count!" -Verbose


$ThreadCount = 50
$time = DemoTNCWithSplitPipeline -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "SplitPipeline TNC Used $time seconds with $ThreadCount Thread count!" -Verbose


$ThreadCount = 100
$time = DemoTNCWithSplitPipeline -ThreadCount $ThreadCount -IPs $ips
Write-Verbose "SplitPipeline TNC Used $time seconds with $ThreadCount Thread count!" -Verbose



# TLDR, this is a great tool that everyone should have. Look how clean that syntax is! Look how fast it performs without any effort! 
# Wow! It even washes your dishes for you and hand dries them!


# Very easy to use. Opens up a realm of possibilities both in scripts and as an admin for doing things quickly that would normally be long loops with just your standard loop-like code.

$allServers = Get-Content "YourSourceForAnArrayOfComputers"

$pingResults = $allServers | Split-Pipeline { process { [PSCustomObject]@{ComputerName = $_; Result = Test-NetConnection -ComputerName $_ -InformationLevel Quiet -WarningAction SilentlyContinue } } }

$pingResults
