# Thread jobs, now with powershell 6.1!

. $PSScriptRoot\helpers\PrepFiles.ps1


$numFiles = 1000

if (-not (Get-Module 'ThreadJob' -ListAvailable))
{
    Install-Module 'ThreadJob' -Force
}

function DemoFilesWithThreadJobs {
    Param(
        $NumJobs
    )
    $numPerJob = $numFiles / $numJobs


    $testPath = PrepFiles $PSScriptRoot 'ThreadJob'

    $allFiles = Get-ChildItem -Path $testPath
    
    $start = Get-Date
    $jobs = foreach ($i in 0..($NumJobs - 1))
    {
        $files = $allFiles | Select-Object -skip ($i * $numPerJob) -first $numPerJob
        $files | Start-ThreadJob -ScriptBlock {
            foreach ($file in $Input)
            {
                $content = Get-Content -Path $file.FullName -Raw
                $content = $content -replace "dolor", "REPLACED-1!"
                $content = $content -replace "elit", "REPLACED-2!"
                $content | Set-Content -Path $file.FullName -Encoding UTF8
                # Write-Verbose "$($file.FullName) modified!" -Verbose
            }
        } -ThrottleLimit $NumJobs
    }
    $jobs | Receive-Job -Wait
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$numJobs = 2
$time = DemoFilesWithThreadJobs -NumJobs $numJobs
Write-Verbose "ThreadJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 4
$time = DemoFilesWithThreadJobs -NumJobs $numJobs
Write-Verbose "ThreadJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 8
$time = DemoFilesWithThreadJobs -NumJobs $numJobs
Write-Verbose "ThreadJob files Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 16
$time = DemoFilesWithThreadJobs -NumJobs $numJobs
Write-Verbose "ThreadJob files Used $time seconds with $numJobs jobs!" -Verbose

<# 
Pros: 
    Baked into powershell core / powershell 6 now (but we're all probably running 5.2 still...).
    Piping syntax.
    I haven't expirimented heavily with it, but it is supposedly more reliable than PoshRSJob.
    Much, much faster than Start-Job (similar to RSJobs).
    Has -InitializationScript to initialize your session 
        (but because it doesn't batch through the pipeline for you, whats the point??? You could just put that in your scriptblock).
Cons:
    What is this $Input syntax? Was making that variable $_ too hard????
    Despite being baked into powershell, no $using:variable syntax. 
        Not a serious complaint, as piping is more explicit, but makes it feel less like lambdas in other programming languages.
    No batching support.
#>


$numJobs = 50
$time = DemoFilesWithThreadJobs -NumJobs $numJobs
Write-Verbose "ThreadJob files Used $time seconds with $numJobs jobs!" -Verbose




# What about IO? Lets scan our network for ICMP responses! This would take many, many minutes in a normal foreach loop.

$ips = 0..100

function DemoTNCWithThreadJobs {
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
        $batchIPs | Start-ThreadJob -ScriptBlock {
            foreach ($ip in $Input)
            {
                $fullIp = "192.168.0.$ip"
                $result = Test-NetConnection -ComputerName $fullIp -InformationLevel Quiet -WarningAction SilentlyContinue
                Write-Output ([PSCustomObject]@{IP = $fullIp; Result = $result})
            }
        } -ThrottleLimit $NumJobs
    }
    $results = $jobs | Receive-Job -Wait
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$numJobs = 40
$time = DemoTNCWithThreadJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "ThreadJob TNC Used $time seconds with $numJobs jobs!" -Verbose




$numJobs = 100
$time = DemoTNCWithThreadJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "ThreadJob TNC Used $time seconds with $numJobs jobs!" -Verbose



