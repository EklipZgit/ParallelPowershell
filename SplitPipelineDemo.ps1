# Split-Pipeline, by nightroman!

function DemoWithSplitPipeline {
    Param(
        $CpuCount
    )
    $start = Get-Date
    $folderPath = Resolve-Path $PSScriptRoot\TestFiles
    
    $testPath = "$PSScriptRoot\output\SplitPipelineFiles"
    $null = mkdir $testPath -Force
    $null = Robocopy.exe /MIR $folderPath $testPath
    start-sleep -seconds 1
    
    $allFiles = Get-ChildItem -Path $testPath
    
    $allFiles | Split-Pipeline -Count $CpuCount -Script {process {
        $content = Get-Content -Path $_.FullName -Raw
        $content = $content -replace "dolor", "REPLACED-1!"
        $content = $content -replace "elit", "REPLACED-2!"
        $content | Set-Content -Path $_.FullName -Encoding UTF8
    } }

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}


$CpuCount = 1
$time = DemoWithSplitPipeline -CpuCount $CpuCount
Write-Verbose "SplitPipeline files Used $time seconds with $CpuCount CPU count!" -Verbose

$CpuCount = 4
$time = DemoWithSplitPipeline -CpuCount $CpuCount
Write-Verbose "SplitPipeline files Used $time seconds with $CpuCount CPU count!" -Verbose

$CpuCount = 8
$time = DemoWithSplitPipeline -CpuCount $CpuCount
Write-Verbose "SplitPipeline files Used $time seconds with $CpuCount CPU count!" -Verbose

<# 
Pros: 
    Allows begin and end blocks (so if you have some setup that must be run once per process, like importing modules, you can use that)
    Very fast compared to Start-Job.
    Very pleasant to use. $_ syntax is very nice. Notice how much less code this took to set up properly than start-job did.

Cons:
    Each job you start is a new powershell process, which is relatively expensive to create. 
    Inconsistent timing, sometimes CPU count start up quickly, sometimes they take forever to start.
    Must reload any modules used in your scriptblock in each job that you start.

#>



# What about IO? Lets scan our network for ICMP responses! This would take many, many minutes in a normal foreach loop.

$ips = 0..100

function DemoTNCWithSplitPipeline {
    Param(
        $CpuCount,
        $IPs
    )
    $start = Get-Date
    $fullIps = foreach ($ipEnd in $ips)
    {
        "192.168.0.$ipEnd"
    }
    
    $results = $fullIps | Split-Pipeline -Count $CpuCount -Script { process {
        $result = Test-NetConnection -ComputerName $_ -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Output [PSCustomObject]@{IP = $_; Result = $result}
    } }

    $usedTime = ((Get-Date) - $start).TotalSeconds
    return $usedTime
}

$CpuCount = 20
$time = DemoTNCWithSplitPipeline -CpuCount $CpuCount -IPs $ips
Write-Verbose "SplitPipeline TNC Used $time seconds with $CpuCount CPU count!" -Verbose


$CpuCount = 50
$time = DemoTNCWithSplitPipeline -CpuCount $CpuCount -IPs $ips
Write-Verbose "SplitPipeline TNC Used $time seconds with $CpuCount CPU count!" -Verbose


$CpuCount = 100
$time = DemoTNCWithSplitPipeline -CpuCount $CpuCount -IPs $ips
Write-Verbose "SplitPipeline TNC Used $time seconds with $CpuCount CPU count!" -Verbose



