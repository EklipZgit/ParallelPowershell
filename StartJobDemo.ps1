# Jobs are the other example of parallel powershell that you may have run into before!



$numFiles = 1000

function DemoFilesWithJobs {
    Param(
        $NumJobs
    )
    $numPerJob = $numFiles / $numJobs

    $folderPath = Resolve-Path $PSScriptRoot\TestFiles
    
    $testPath = "$PSScriptRoot\output\StartJobFiles"
    $null = mkdir $testPath -Force
    $null = Robocopy.exe /MIR $folderPath $testPath
    start-sleep -seconds 1

    $allFiles = Get-ChildItem -Path $testPath
    
    $start = Get-Date
    $jobs = foreach ($i in 0..($NumJobs - 1))
    {
        $files = $allFiles | Select-Object -skip ($i * $numPerJob) -first $numPerJob
        Start-Job -ScriptBlock {
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
    
    $jobs | Receive-Job -Wait
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$numJobs = 1
$time = DemoFilesWithJobs -NumJobs $numJobs
Write-Verbose "StartJob Used $time seconds with $numJobs jobs!" -Verbose

$numJobs = 5
$time = DemoFilesWithJobs -NumJobs $numJobs
Write-Verbose "StartJob Used $time seconds with $numJobs jobs!" -Verbose

<# 
Pros: 
    Baked into powershell. $using variable is nice.
    Very reliable. I have not run into any issues with this command behaving strangely.

Cons:
    Each job you start is a new powershell process, which is relatively expensive to create. 
    Inconsistent timing, sometimes jobs start up quickly, sometimes they take forever to start.
    Must reload any modules used in your scriptblock in each job that you start.

#>


$numJobs = 50
$time = DemoFilesWithJobs -NumJobs $numJobs
Write-Verbose "StartJob Used $time seconds with $numJobs jobs!" -Verbose




# What about IO? Lets scan our network for ICMP responses! This would take many, many minutes in a normal foreach loop.

$ips = 0..100

function DemoTNCWithJobs {
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
        Start-Job -ScriptBlock {
            foreach ($ip in $using:batchIPs)
            {
                $fullIp = "192.168.0.$ip"
                $result = Test-NetConnection -ComputerName $fullIp -InformationLevel Quiet -WarningAction SilentlyContinue
                Write-Output [PSCustomObject]@{IP = $fullIp; Result = $result}
            }
        }
    }
    
    $results = $jobs | Receive-Job -Wait
    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$numJobs = 40
$time = DemoTNCWithJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "StartJob TNC Used $time seconds with $numJobs jobs!" -Verbose




$numJobs = 100
$time = DemoTNCWithJobs -NumJobs $numJobs -IPs $ips
Write-Verbose "StartJob TNC Used $time seconds with $numJobs jobs!" -Verbose





# Can be used with Invoke-Command with the -AsJob flag!