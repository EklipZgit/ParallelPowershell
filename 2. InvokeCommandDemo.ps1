
# Invoke-Command is useful for the case where you want to talk to lots of servers!

# Lets get the highest CPU usage process on each box in the loandepot QA1 environment.

$computers = Get-LDserver -Environment QA1 | select -ExpandProperty ComputerName

$computers.Count


$HighCpuProcesses = Invoke-Command -ThrottleLimit 50 -ComputerName $computers { 
    $result = Get-Process | Sort CPU -descending | Select -first 1 -Property ProcessName,CPU
    Write-Output ([PSCustomObject]@{'ComputerName' = $ENV:ComputerName; 'ProcessName' = $result.ProcessName; 'CPU' = $result.CPU})
}

$HighCpuProcesses | Format-Table
