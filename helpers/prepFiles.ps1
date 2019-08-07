Function PrepFiles {
    Param(
        $Root, 
        $Prefix
    )
    $folderPath = Resolve-Path "$Root\TestFiles"
    
    $testPath = "$Root\output\$($Prefix)Files"
    $null = mkdir $testPath -Force
    $null = Robocopy.exe /MIR $folderPath $testPath
    start-sleep -Milliseconds 100
    return $testPath
}