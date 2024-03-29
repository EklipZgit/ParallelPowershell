# Create 1000 large files. This is about 150 MB of text generated total.

$null = mkdir $PSScriptRoot\testFiles -Force
$bigString = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum luctus, elit a consequat vestibulum, turpis turpis feugiat odio, lobortis viverra quam velit ac ex. Nulla facilisi. Integer egestas molestie urna ac euismod. Suspendisse at dapibus sapien, eget eleifend ligula. Vivamus consequat laoreet nisi eu auctor. Suspendisse cursus leo sed sapien pellentesque, ac varius ligula posuere. Nunc non turpis vitae lacus tempor dictum. Mauris suscipit pulvinar interdum. Fusce varius id augue ut tristique. Morbi nisi erat, blandit non bibendum eget, vulputate pellentesque augue. Interdum et malesuada fames ac ante ipsum primis in faucibus. Integer tempus tempor gravida. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris convallis turpis in ex sagittis efficitur. Mauris accumsan tellus risus. Aliquam volutpat auctor metus vel bibendum.

Sed bibendum, justo non egestas semper, dui dolor porttitor nibh, a pulvinar purus lectus ut justo. Phasellus mattis est sed leo suscipit, eu pretium dui sollicitudin. Duis non iaculis eros. Vestibulum ac odio nec nulla faucibus ultrices. Donec in lectus in nisl vestibulum tempus. Integer nulla erat, commodo sit amet commodo et, pulvinar sed mi. Quisque id ultricies sem. Vivamus id posuere nisi, nec iaculis diam. Duis aliquet lacus non erat posuere, nec vestibulum elit commodo. Pellentesque nec tellus quis odio pellentesque tempor eu id ex. In hac habitasse platea dictumst. Sed ut eleifend ipsum. Etiam tincidunt, dui lobortis gravida dapibus, justo lectus vestibulum enim, eget euismod mauris erat non urna. Curabitur sed congue risus. Praesent suscipit pretium nulla, eu elementum ex suscipit id. Morbi sit amet tincidunt metus, porta sodales erat.

Donec non tortor congue, pulvinar elit eu, eleifend mauris. Fusce vel malesuada urna. Cras a interdum ligula, a porttitor metus. Donec vel porta lacus, efficitur pulvinar elit. Integer dolor sapien, dapibus sit amet quam hendrerit, fermentum mattis lectus. Duis maximus lacus ac lacinia scelerisque. Aliquam hendrerit augue non efficitur laoreet. Donec feugiat dolor nulla, nec vestibulum tortor congue vel. Donec at dolor magna. Duis mollis tristique lacinia. Aenean a varius urna.

Nulla vel arcu pretium, ornare ligula id, posuere leo. Nulla elementum quam eu magna sodales bibendum. Nullam laoreet erat vel aliquet venenatis. Nunc vitae accumsan augue. Ut porttitor sed augue vel tincidunt. Quisque laoreet dui vitae urna porta pulvinar. Quisque eleifend nibh sed felis posuere, egestas consequat erat lacinia. Pellentesque non nulla sodales, dictum quam eu, congue dolor. Donec ultricies est nibh, id mollis ligula viverra eu.

Etiam bibendum aliquet elit eget congue. Curabitur et euismod ligula, dignissim blandit eros. Aliquam at efficitur ipsum, et fermentum felis. Duis condimentum luctus diam eu laoreet. Nulla sed maximus felis, at laoreet mauris. Sed mollis a tortor non lobortis. Maecenas tempus bibendum felis, congue condimentum enim malesuada sed. Donec et nisl posuere dolor lobortis rhoncus."

$bigString *= 50

foreach ($i in 0..1000) 
{ 
	$bigString | set-content -path "$PSScriptRoot\testFiles\$i.txt"
}



# Quick baseline single threaded test:

$folderPath = Resolve-Path $PSScriptRoot\TestFiles
    
$testPath = "$PSScriptRoot\output\SingleThreadedFiles"
$null = mkdir $testPath -Force
$null = Robocopy.exe /MIR $folderPath $testPath

$allFiles = Get-ChildItem -Path $testPath

$start = Get-Date
foreach ($file in $allFiles)
{
	$content = Get-Content -Path $file.FullName -Raw
	$content = $content -replace "dolor", "REPLACED-1!"
	$content = $content -replace "elit", "REPLACED-2!"
	$content | Set-Content -Path $file.FullName -Encoding UTF8
}

$usedTime = ((Get-Date) - $start).TotalSeconds
Write-Verbose "SingleThreaded files used $usedTime seconds!" -Verbose