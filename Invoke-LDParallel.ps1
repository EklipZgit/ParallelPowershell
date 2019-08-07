
function Invoke-LDParallel
{
    <#
    .SYNOPSIS
    Invoke-LDParallel, invokes stuff multithreaded.
    Results have a .Results property, a .SourceObject property, and a .Error property. ALWAYS check the .Error property.

    .DESCRIPTION
    Invoke-LDParallel, invokes stuff multithreaded

    .PARAMETER InputObject
    The objects to invoke parallel over

    .PARAMETER ScriptBlock
    The scriptblock to execute on the objects. $_ for input object.

    .PARAMETER Arguments
    Array of arguments to be passed to the scriptblock.

    .PARAMETER Throttle
    How many threads to use. Default 5.

    .PARAMETER BatchCount
    How many batches (threads) to split the input up into.

    .PARAMETER BatchSize
    Alternative to batchcount, this is how many objects should be in each batch. Batch count will be adjusted accordingly.

    .PARAMETER Begin
    Script block that should run once per runspace (rather than once per batch object). Use this to import or setup variables, etc.

    .PARAMETER AsList
    Batches the normal way, but then calls the scriptblock with the whole batch of objects as a list, rather than for each object individually.
    Make sure you map your input to your output in some way as part of the output when using this switch, otherwise you won't be able to track which item failed, etc.

    .PARAMETER ReceiveLive
    Gets job output as jobs finish (in the same order they were started, not necessarily in the order they finish).
    This is less performant but allows you pipe some output earlier without waiting for all batches to finish and shows verbose messages for debug output as jobs complete.
    BE AWARE that input streams are not output in the order receieved. ALL verbose output from an entire job will be output before ALL output stream output, etc.
    If you are trying to use output for debugging, make sure all of your output is the same type, EG verbose output, in order to ensure correct ordering of output messages.

    .PARAMETER DebugNoRS
    Runs everything serially in the same runspace (so that debug breakpoints can be hit in the scriptblock).
    For debugging purposes only, this runs much slower than ForEach-Object.

    .EXAMPLE
    $results = $FileList | Invoke-LDParallel -Throttle 10 -BatchCount 40 -ScriptBlock {
        [System.IO.File]::ReadAllText($_.FullName) | ConvertFrom-LDJson
    }
    foreach ($result in $results)
    ...
    #>
    [CmdletBinding(DefaultParameterSetName = 'BatchCount')]
    Param(
        [Parameter(ValueFromPipeline)]
        $InputObject,
        [Parameter()]
        [ScriptBlock] $ScriptBlock,
        [Parameter()]
        [array] $Arguments = $null,
        [Parameter()]
        [int] $Throttle = 5,
        [Parameter(ParameterSetName = 'BatchCount')]
        $BatchCount,
        [Parameter(ParameterSetName = 'BatchSize')]
        $BatchSize,
        [Parameter()]
        [ScriptBlock] $Begin,
        [Parameter()]
        [switch] $AsList,
        [Parameter()]
        [switch] $ReceiveLive,
        [Parameter()]
        [switch] $DebugNoRS
    )
    begin
    {
        $ldpar_list = [System.Collections.ArrayList]::new()
    }
    process
    {
        foreach ($obj in $InputObject)
        {
            [void] $ldpar_list.Add($obj)
        }
    }
    end
    {
        if (-Not $DebugNoRS)
        {
            if (-not $BatchSize)
            {
                if (-not $BatchCount)
                {
                    $BatchCount = $Throttle * 3
                }
                $BatchSize = [Math]::Ceiling($ldpar_list.Count / $BatchCount)
            }
            $batches = Group-Batch -ToBatch $ldpar_list.ToArray() -BatchSize $BatchSize

            $loc = Get-Location
            $newRsJobs = Start-RSJob -InputObject $batches -Throttle $Throttle -ScriptBlock {
                Param($ldpar_batchObject)
                $ErrorActionPreference = 'Stop'
                [system.diagnostics.stopwatch]$stopwatch = [system.diagnostics.stopwatch]::new()
                $ldpar_block = [ScriptBlock]::Create(($Using:ScriptBlock).ToString())
                Set-Location $Using:loc
                $beginError = $null
                if ($Using:Begin)
                {
                    $ldpar_begin_block = [ScriptBlock]::Create(($Using:Begin).ToString())
                    try
                    {
                        Invoke-Command -ScriptBlock $ldpar_begin_block -NoNewScope -ErrorAction 'Stop'
                    }
                    catch
                    {
                        $beginError = $_
                    }
                }
                if ($Using:AsList)
                {
                    $stopwatch.Restart()
                    $ldpar_itResult = [PSCustomObject]@{
                        SourceObject = $ldpar_batchObject.Batch
                        Results      = $null
                        Error        = $beginError
                        ElapsedTime  = $null
                    }
                    if (-Not $beginError)
                    {
                        try
                        {
                            $ldpar_itResult.Results = $ldpar_block.InvokeWithContext($null, @((New-Object PSVariable '_', $ldpar_batchObject.Batch),(New-Object PSVariable 'PSItem', $ldpar_batchObject.Batch)), $Using:Arguments)
                        }
                        catch
                        {
                            $ldpar_itResult.Error = $_
                        }
                    }
                    $stopwatch.Stop()
                    $ldpar_itResult.ElapsedTime = $stopwatch.Elapsed
                    $ldpar_itResult
                }
                else
                {
                    foreach ($ldpar_obj in $ldpar_batchObject.Batch)
                    {
                        $stopwatch.Restart()
                        $ldpar_itResult = [PSCustomObject]@{
                            SourceObject = $ldpar_obj
                            Results      = $null
                            Error        = $beginError
                            ElapsedTime  = $null
                        }
                        if (-Not $beginError)
                        {
                            try
                            {
                                $ldpar_itResult.Results = $ldpar_block.InvokeWithContext($null, @((New-Object PSVariable '_', $ldpar_obj),(New-Object PSVariable 'PSItem', $ldpar_obj)), $Using:Arguments)
                            }
                            catch
                            {
                                $ldpar_itResult.Error = $_
                            }
                        }
                        $stopwatch.Stop()
                        $ldpar_itResult.ElapsedTime = $stopwatch.Elapsed
                        $ldpar_itResult
                    }
                }
            }

            if ($ReceiveLive)
            {
                foreach ($rsJob in $newRSJobs)
                {
                    $null = Wait-RSJob -Job $rsJob
                    Receive-RSJob -Job $rsJob | ForEach-Object {
                        if ($_.Error)
                        {
                            $_.Error = Get-CleanRSJobException -ErrorRecord $_.Error
                        }
                        Write-Output $_
                    }
                }
            }
            else
            {
                $null = Wait-RSJob -Job $newRsJobs
                Receive-RSJob -Job $newRsJobs | ForEach-Object {
                    if ($_.Error)
                    {
                        $_.Error = Get-CleanRSJobException -ErrorRecord $_.Error
                    }
                    Write-Output $_
                }
            }
            $null = Remove-RSJob -Job $newRsJobs -Force
        }
        else
        {
            [system.diagnostics.stopwatch]$stopwatch = [system.diagnostics.stopwatch]::new()

            if ($Begin)
            {
                Invoke-Command -ScriptBlock $Begin -NoNewScope -ErrorAction 'Stop'
            }

            # No runspaces
            Write-Warning "DebugNoRS flag was passed. This means the command will not run in parallel, allowing you to set breakpoints and debug the scriptblock, however losing all parallelization."
            if ($AsList)
            {
                $ldpar_array = $ldpar_list.ToArray()
                $stopwatch.Restart()
                $ldpar_itResult = [PSCustomObject]@{
                    SourceObject = $ldpar_array
                    Results      = $null
                    Error        = $null
                    ElapsedTime  = $null
                }
                try
                {
                    # $ldpar_itResult.Results = Invoke-Command -ScriptBlock $ScriptBlock.GetNewClosure() -ArgumentList $Arguments -ErrorAction Stop -NoNewScope
                    $ldpar_itResult.Results = $ScriptBlock.InvokeWithContext($null, @((New-Object PSVariable '_', $ldpar_array),(New-Object PSVariable 'PSItem', $ldpar_array)), $Arguments)
                }
                catch
                {
                    $ldpar_itResult.Error = $_
                }
                $stopwatch.Stop()
                $ldpar_itResult.ElapsedTime = $stopwatch.Elapsed
                $ldpar_itResult
            }
            else
            {
                $ldpar_itResults = foreach ($ldpar_obj in $ldpar_list.ToArray())
                {
                    $stopwatch.Restart()
                    $ldpar_itResult = [PSCustomObject]@{
                        SourceObject = $ldpar_obj
                        Results      = $null
                        Error        = $null
                        ElapsedTime  = $null
                    }
                    try
                    {
                        # $ldpar_itResult.Results = Invoke-Command -ScriptBlock $ScriptBlock.GetNewClosure() -ArgumentList $Arguments -ErrorAction Stop -NoNewScope
                        $ldpar_itResult.Results = $ScriptBlock.InvokeWithContext($null, @((New-Object PSVariable '_', $ldpar_obj),(New-Object PSVariable 'PSItem', $ldpar_obj)), $Arguments)
                    }
                    catch
                    {
                        $ldpar_itResult.Error = $_
                    }
                    $stopwatch.Stop()
                    $ldpar_itResult.ElapsedTime = $stopwatch.Elapsed
                    $ldpar_itResult
                }
            }
            Write-Output $ldpar_itResults
        }
    }
}
