
&git --version | Out-Null
if (-not $?) {
	throw "Git does not exist"
}

&git update-index -q --refresh | Out-Null
$Changed = (&git diff-index --name-only HEAD --).Length -gt 0

if ($Changed) {
	throw "Uncommitted changes detected, please commit, stash or discard your changes"
}

$BaseDirectory = Split-Path $MyInvocation.MyCommand.Path
$OutputDirectory = $Home

$ExistingFiles = @()
$ExistingFiles += Get-ChildItem (Join-Path $BaseDirectory "files")
$ExistingFiles += Get-ChildItem (Join-Path $BaseDirectory (Join-Path "private" "files"))

$ExistingFiles | % {
	$FileName = $_.Name
	$ExistingFile = $_.FullName
	$OutputFile = Join-Path $OutputDirectory $FileName
	if (Test-Path $OutputFile) {
		Write-Host ("Copying [{0}] to [{1}]" -f @($OutputFile, $ExistingFile))
		Copy-Item -Path $OutputFile -Destination $ExistingFile
	} else {
		Write-Host ("Skipping updating [{0}] as [{1}] does not exist" -f @($FileName, $OutputFile))
	}
}
