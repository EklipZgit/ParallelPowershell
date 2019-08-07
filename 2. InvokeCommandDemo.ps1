
# Invoke-Command is useful for the case where you want to talk to lots of servers!

# Lets get the highest CPU usage process on each box below! (Replace with your own source of boxes...)

$computers = @(
    "S-MY-SERVER-1"
    "S-MY-SERVER-2"
    "S-MY-SERVER-3"
    "S-MY-SERVER-4"
    "S-MY-SERVER-5"
    "S-MY-SERVER-6"
    "S-MY-SERVER-7"
    "S-MY-SERVER-8"
)

$computers.Count

# Note that it auto-appends PSComputerName to the object that gets output. 
# Note that server order input -> output is not preserved.
$highCpuProcesses = Invoke-Command -ThrottleLimit 8 -ComputerName $computers { 
    $result = Get-Process | Sort CPU -descending | Select -first 1 -Property ProcessName,CPU
    Write-Output ([PSCustomObject]@{'ProcessName' = $result.ProcessName; 'CPU' = $result.CPU})
}

$highCpuProcesses | Format-Table
