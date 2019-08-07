Function PrepFiles {
    Param(
        $Root, 
        $Prefix
    )
    $folderPath = Resolve-Path "$Root\TestFiles"
    
    $testPath = "$Root\output\$($Prefix)Files"
    $null = mkdir $testPath -Force
    $null = Robocopy.exe /MIR $folderPath $testPath
    # Sleep for a moment to make our tests more consistent, something something disk caches, locked files.
    start-sleep -Milliseconds 100
    return $testPath
}