# RS Jobs are a faster alternative



$numFiles = 1000

function DemoFilesWithRSJobs {
    Param(
        $NumJobs
    )
    $numPerJob = $numFiles / $numJobs

    $folderPath = Resolve-Path $PSScriptRoot\TestFiles
    
    $testPath = "$PSScriptRoot\output\StartRSJobFiles"
    $null = mkdir $testPath -Force
    $null = Robocopy.exe /MIR $folderPath $testPath
    start-sleep -seconds 1

    $allFiles = Get-ChildItem -Path $testPath
    
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
                # Write-Verbose "$($file.FullName) modified!" -Verbose
            }
        }
    }
    $null = $jobs | Wait-RSJob
    $jobs | Receive-RSJob
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$numJobs = 1
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 5
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose

<# 
Pros: 
    Supports piping and $_ syntax. (Didn't use here since batching was used still)
    Much faster startup than Start-Job due to using Runspaces (+threads) rather than Processes.
Cons:
    Jobs are not batched however unlike Split-Pipeline, so performance will decrease with 
        large numbers of small items similar to Start-Job. 
    Personally I have had issues with loading modules in RSJob threads in parallel, 
        sometimes the module load freaks out. I wrap them in try-catches and retry.
#>


$numJobs = 20
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 50
$time = DemoFilesWithRSJobs -NumJobs $numJobs
Write-Verbose "RSJob files Used $time seconds with $numJobs jobs!" -Verbose




# What about IO? Lets scan our network for ICMP responses! This would take many, many minutes in a normal foreach loop.

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
                Write-Output [PSCustomObject]@{IP = $fullIp; Result = $result}
            }
        }
    }
    
    $null = $jobs | Wait-RSJob
    $results = $jobs | Receive-RSJob
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$numJobs = 40
$time = DemoTNCWithRSJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "RSJob TNC Used $time seconds with $numJobs jobs!" -Verbose




$numJobs = 100
$time = DemoTNCWithRSJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "RSJob TNC Used $time seconds with $numJobs jobs!" -Verbose





# Can be used with Invoke-Command with the -AsJob flag!