if ((Get-ExecutionPolicy) -eq "Restricted") {
	Set-ExecutionPolicy RemoteSigned
}

if (Get-Module -ListAvailable -Name PsGet) {
	Import-Module PsGet
} else {
	"Could not find PsGet, attempting to install"
	try {
		(New-Object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | Invoke-Expression
		Import-Module PsGet
	} catch {
		"Could not install PsGet: $_"
	}
}

$ScriptsFolder = Join-Path $Home "Documents\WindowsPowershell\Scripts"
if (-not (Test-Path $ScriptsFolder)) {
	New-Item $ScriptsFolder -Type directory | Out-Null
}

Function Initialize-PoshCodeScript ([string] $ScriptName, [int] $ScriptId) {
	$ScriptFile = Join-Path $ScriptsFolder "$ScriptName.ps1"
	if (-not (Test-Path $ScriptFile)) {
		"Could not find script $ScriptName, attempting to download"
		try {
			Get-PoshCode -Id $ScriptId -PassThru | Set-Content $ScriptFile
		} catch {
			"Could not download $($ScriptName): $_"
		}
	}
}

Import-Module PsBundle

try {
Register-Module -Name PoshCode -Source "http://poshcode.org/PoshCode.psm1" -ProviderType "psm1"
} catch {
}

try {
Register-Module -Name Process-Helpers -Source "unknown"
} catch {
}

try {
Register-Module -Name DotNet-Helpers -Source "unknown"
} catch {
}

Initialize-PoshCodeScript New-CommandWrapper 2197

Register-Module -Name PowerTab -Source "https://hg.codeplex.com/powertab" -ProviderType "hg"
Register-Module -Name posh-hg -Source "JeremySkinner/posh-hg" -ProviderType "github"

try {
Register-Module -Name Work-Helpers -Source "unknown"
} catch {
}

Set-Alias vim "gvim"
Set-Alias grep Select-String
Set-Alias tree Show-Tree.ps1

Set-Alias nunit Invoke-NUnit
Set-Alias mstest Invoke-MsTest
Set-Alias msbuild Invoke-MsBuild
Set-Alias devenv Invoke-DevEnv

Function Test-Command ([string] $Name) {
	Get-Command -Name $Name -ErrorAction SilentlyContinue | Out-Null
	return $?
}

Function Get-Constructors ([Type] $type) {
	$type.GetConstructors() | % {
		"$($type.FullName)($(@($_.GetParameters() | % { "$($_.ParameterType) $($_.Name)" }) -join ", "))"
	}
}

Function Get-Methods ([Type] $type) {
	$type.GetMethods() | % {
		"$($_.ReturnType) $($type.FullName).$($_.Name)($(@($_.GetParameters() | % { "$($_.ParameterType) $($_.Name)" }) -join ", "))"
	}
}

Function Get-StaticMethods ([Type] $type) {
	$type.GetMethods([System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::Public) | % {
		"$($_.ReturnType) $($type.FullName).$($_.Name)($(@($_.GetParameters() | % { "$($_.ParameterType) $($_.Name)" }) -join ", "))"
	}
}

Function Get-Properties ([Type] $type) {
	$type.GetProperties() | % {
		"$($_.PropertyType) $($type.FullName).$($_.Name)"
	}
}

function To-HumanReadable ($size, $currentSuffix=' ') {
	$suffixTransitions = @{ ' ' = 'K'; 'K' = 'm'; 'm' = 'g'; 'g' = 'p' }

	while ($size -gt 4096) {
		$size = $size / 1024
		$currentSuffix = $suffixTransitions[$currentSuffix]
	}

	if ($size -ne $null) {
		return "{0}{1}" -f $size.ToString("N0"), $currentSuffix
	} else {
		return ""
	}
}

function Write-Color-LS {
	param ([string]$color = "white", $file)
	Write-host ("{0,-7} {1,15} {2,8} {3}" -f $file.mode, $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm"), (To-HumanReadable $file.length), $file.name) -foregroundcolor $color 
}

if (Test-Command New-CommandWrapper) {
	New-CommandWrapper Out-Default -Process {
		$regex_opts = ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

		$compressed = New-Object System.Text.RegularExpressions.Regex(
				'\.(zip|tar|gz|rar|jar|war)$', $regex_opts)
		$executable = New-Object System.Text.RegularExpressions.Regex(
				'\.(exe|bat|cmd|py|pl|ps1|psm1|vbs|rb|reg)$', $regex_opts)
		$text_files = New-Object System.Text.RegularExpressions.Regex(
				'\.(txt|cfg|conf|ini|csv|log|xml|java|c|cpp|cs)$', $regex_opts)

		if(($_ -is [System.IO.DirectoryInfo]) -or ($_ -is [System.IO.FileInfo])) {

			if ($_ -is [System.IO.FileInfo]) {
				$new_parent = $_.Directory.FullName
			} else {
				$new_parent = $_.Parent.FullName
			}

			if ($parent -ne $new_parent) {
				$parent = $new_parent
				Write-Host
				Write-Host "Directory: " -noNewLine
				Write-Host " $parent`n" -foregroundcolor "Magenta"
				Write-Host "Mode       LastWriteTime   Length Name"
				Write-Host "----       -------------   ------ ----"
			}

			if ($_ -is [System.IO.DirectoryInfo]) {
				Write-Color-LS "Magenta" $_
			} elseif ($compressed.IsMatch($_.Name)) {
				Write-Color-LS "DarkGreen" $_
			} elseif ($executable.IsMatch($_.Name)) {
				Write-Color-LS "Red" $_
			} elseif ($text_files.IsMatch($_.Name)) {
				Write-Color-LS "Yellow" $_
			} else {
				Write-Color-LS "White" $_
			}

			$_ = $null
		}
	} -end {
		write-host ""
	}
}

function Write-Indented ([Object]$Object, [ConsoleColor]$ForegroundColor = "Green") {
	Write-Host -NoNewLine $Global:Indent
	Write-Host $Object -ForegroundColor $ForegroundColor
}
function Increase-Indent {
	$Global:Indent += "    "
}
function Decrease-Indent {
	$Global:Indent = $Global:Indent.Substring(0, $Global:Indent.Length - 4)
}

function Set-ConsoleTitle ($Title) {
	if ($Host -and $Host.UI -and $Host.UI.RawUI) {
		$Host.UI.RawUI.WindowTitle = $Title
	}
}

function prompt {
	$remainingWidth = $HOST.UI.RawUI.WindowSize.Width - "$($ENV:USERNAME) at $($ENV:COMPUTERNAME)".Length
	$dir = $pwd.Path

	if ($dir.StartsWith($HOME)) {
		$dir = "~" + $dir.Substring($HOME.Length)
	}

	if ($dir.StartsWith("D:\sources")) {
		$dir = "÷" + $dir.Substring("D:\sources".Length)
	}

	Set-ConsoleTitle $dir

	if ($dir.Length -gt $remainingWidth - 8) {
		$dir = "…" + $dir.Substring($dir.Length - $remainingWidth + 8)
	}

	$spacerLength = $remainingWidth - $dir.Length - 1

	Write-Host
	Write-Host $ENV:USERNAME -NoNewLine -ForegroundColor Green
	Write-Host " at " -NoNewLine -ForegroundColor White
	Write-Host $ENV:COMPUTERNAME -NoNewLine -ForegroundColor Green
	Write-Host (" " * $spacerLength) -NoNewLine
	Write-Host $dir -ForegroundColor Magenta -NoNewLine
	Write-Host

	Write-Host (Get-Date).ToString("HH:mm") -NoNewline -ForegroundColor Blue
#Write-VcsStatus

	return " > "
}

$env:PATH = "$($env:APPDATA)\npm;C:\Program Files\nodejs;$($env:PATH)"

$node_version = node.exe -p -e "process.versions.node + ' (' + process.arch + ')'"
Write-Debug "Your environment has been set up for using Node.js $node_version and NPM"

$env:EDITOR = 'gvim'

Function Force-ResolvePath ([String] $Path) {
	$ResolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue -ErrorVariable ForceResolvePathError
	if ($ResolvedPath) {
		$ResolvedPath = $ResolvedPath.Path
	} else {
		$ResolvedPath = $ForceResolvePathError[0].TargetObject
	}
	return $ResolvedPath
}

function Get-WebFile {
	Param (
		[Parameter(Mandatory = $true)]
		$Url,
		[Parameter(Mandatory = $true)]
		$Path
	)
	$Path = Force-ResolvePath $Path
	(New-Object System.Net.WebClient).DownloadFile($Url, $Path)
}

function Expand-Archive {
	Param (
		[Parameter(Mandatory = $true)]
		$File,
		[Parameter(Mandatory = $true)]
		$Path
	)
	$File = (Resolve-Path $File).Path
	$Path = Force-ResolvePath $Path
	$Shell = New-Object -Com Shell.Application
	$ZipFile = $Shell.Namespace($File)
	$Destination = $Shell.Namespace($Path)
	$Destination.CopyHere($ZipFile.Items())
}

Set-Alias wget Get-WebFile
Set-Alias extract Expand-Archive
