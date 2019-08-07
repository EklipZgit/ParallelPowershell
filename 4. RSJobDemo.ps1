# RS Jobs are a faster alternative

. $PSScriptRoot\helpers\PrepFiles.ps1

if (-not (Get-Module 'PoshRSJob' -ListAvailable))
{
    Install-Module 'PoshRSJob' -Force
}

function DemoFilesWithRSJobs {
    Param(
        $NumJobs
    )

    $testPath = PrepFiles $PSScriptRoot 'RSJob'

    # Again, note the boilerplate batching code required for this to run fast, rather than spinning up a whole runspace per file.
    $allFiles = Get-ChildItem -Path $testPath
    $numFiles = $allFiles.Count
    $numPerJob = $numFiles / $numJobs
    
    $start = Get-Date
    $jobs = foreach ($i in 0..($NumJobs - 1))
    {
        $files = $allFiles | Select-Object -skip ($i * $numPerJob) -first $numPerJob
        Start-RSJob -ScriptBlock {
            foreach ($file in $using:files)
            {
                $content = Get-Content -Path $file.FullName -Raw
                $content = $content -replace "dolor", "REPLACED-1!"
                $content = $content -replace "elit", "REPLACED-2!"
                $content | Set-Content -Path $file.FullName -Encoding UTF8
            }
        }
    }
    $null = $jobs | Wait-RSJob | Receive-RSJob
    $jobs | Remove-RSJob
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$numJobs = 2
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 5
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 8
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 16
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose

<# 
Pros: 
    Supports piping and $_ syntax. (Didn't use here since batching was used still)
    Supports $using:variable syntax
    Much faster startup than Start-Job due to using Runspaces (+threads) rather than Processes.
Cons:
    Have to Wait-RSJob before Receive-RSJob. Why did we go a step backwards in technology from Start-Job?
    Jobs do not batch items automatically, so performance will decrease with 
        large numbers of small items similar to Start-Job. 
    Personally I have had issues with loading modules in RSJob threads in parallel, sometimes the module load freaks out. 
        I wrap them in try-catches and retry a few times and it is fairly reliable after that. Quite annoying.
    No batching support, so lots of boilerplate code for managing your own batches of objects.
    RSJob doesn't seem to be able to use maximal CPU usage unlike Start-Job.
        Even if you use 8+ threads on a 4 core machine, you'll find it struggles to use more than 75% of the CPU on CPU-Bound workloads
        unless you create SO MANY rsjobs that you're wasting a ton of CPU context-switching between threads.
#>


$numJobs = 50
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose




# Lets try our Test-NetConnection ICMP pings with RSJobs!

$ips = 0..100

function DemoTNCWithRSJobs {
    Param(
        $NumJobs,
        $IPs
    )
    $count = $IPs.Count
    
    $start = Get-Date
    $jobs = foreach ($i in 0..($NumJobs - 1))
    {
        $startIdx = [int]($i*$count / $NumJobs)
        $endIdx = [int](($i+1)*$count / $NumJobs) - 1
        $batchIPs = $IPs[$startIdx..$endIdx]
        Start-RSJob -ScriptBlock {
            foreach ($ip in $using:batchIPs)
            {
                $fullIp = "192.168.0.$ip"
                $result = Test-NetConnection -ComputerName $fullIp -InformationLevel Quiet -WarningAction SilentlyContinue
                Write-Output ([PSCustomObject]@{IP = $fullIp; Result = $result})
            }
        } -Throttle 100
        # -Throttle doesn't actually apply unless you are piping to Start-RSJob...
    }
    
    $results = $jobs | Wait-RSJob | Receive-RSJob
    $jobs | Remove-RSJob
    
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$numJobs = 40
$time = DemoTNCWithRSJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "RSJob TNC Used $time seconds with $numJobs jobs!" -Verbose




$numJobs = 100
$time = DemoTNCWithRSJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "RSJob TNC Used $time seconds with $numJobs jobs!" -Verbose

Get-RSJob | Remove-RSJob -ErrorAction SilentlyContinue
# 