#################################
# Functions for release script. #
#################################

# Returns the current ROOTMAP version number.
Function Get-CurrentVersionNumber {
  [CmdletBinding()]
  Param()

  $path = (Get-ChildItem -Recurse -Include RmGetOpts.cpp | Select-Object -First 1).FullName
  $content = Get-Content $path
  $major = [convert]::ToInt32([regex]::Match($content, 'VersionMajor\s*?=\s*?(\d+?)\s*?;').Groups[1].Value, 10)
  if (-not $?) { throw 'Major version number not found.' }
  $minor = [convert]::ToInt32([regex]::Match($content, 'VersionMinor\s*?=\s*?(\d+?)\s*?;').Groups[1].Value, 10)
  if (-not $?) { throw 'Minor version number not found.' }
  $patch = [convert]::ToInt32([regex]::Match($content, 'VersionPatch\s*?=\s*?(\d+?)\s*?;').Groups[1].Value, 10)
  if (-not $?) { throw 'Patch version number not found.' }

  return ($major, $minor, $patch)
}

# TODO use ValidateSet
Function Test-Args {
  [CmdletBinding()]
  Param([String[]]$theArgs)

  # TODO if release type is explicit, test second arg for x.y.z pattern
  $ok = $theArgs.length -eq 2 -or $theArgs.length -eq 3
  $releaseTypes = 'major', 'minor', 'patch', 'explicit'
  if ($ok) {
    $ok = $releaseTypes.Contains($theArgs[0])
  }
  if (!$ok) {
    $errorMessage = @'
Please supply a release type (major|minor|patch) and release notes e.g. "* Updated 3D graphics * Fixed output rule timing bug".
Example usage:
> release.ps1 minor "Added a new rendering option."

Alternatively, to produce a release with a specific version number, use "explicit" with version number string, followed by release notes.
Example usage:
> release.ps1 explicit "1.1.42" "Corrected buggy patch release 1.1.42."

'@
    Write-Host $errorMessage
  }

  if ($theArgs[0] -eq 'explicit') {
    # If the caller is trying to set an explicit version, it must be major.minor.patch
    $versionRegex = [regex]"^(\d+.){2}\d+$"
    $ver = $theArgs[1]
    if ($ver -match $versionRegex -eq $False) {
      $ok = $False
      $errorMessage = @"
Invalid version number "$ver". Explicit version must be in the format major.minor.patch, e.g. 2.0.15.
"@
      Write-Host $errorMessage
    }
  }
  return $ok
}

Function Get-GitExe {
  [CmdletBinding()]
  Param()
  try {
    & 'git' | Out-Null # Attempt to use the version of Git on the PATH
    return 'git'
  }
  catch {
    # If we can't find a version of Git on the path, take a reasonable guess.
    # TODO: Make this more robust.
    return "$Env:programfiles\git\bin\git.exe"
  }
}

# TODO DRY these two out

Function Receive-GitRemoteCommits {
  [CmdletBinding()]
  Param(
    [Parameter(Position = 0)][String]$gitExe,
    [Parameter(ValueFromRemainingArguments = $true)][String[]]$branchNames
  )

  # Local function.
  Function Pull {
    (& $gitExe pull) | Write-Host
    if ($LASTEXITCODE) {
      throw "Failed when trying to pull changes from remote (Exit code $LASTEXITCODE)."
    }
  }

  if ($null -ne $branchNames) {
    foreach ($b in $branchNames) {
      (& $gitExe checkout $b) | Write-Host
      Pull
    }
  }
  else {
    Pull
  }
}

Function Send-GitLocalCommits {
  [CmdletBinding()]
  Param(
    [Parameter(Position = 0)][String]$gitExe,
    [Parameter(ValueFromRemainingArguments = $true)][String[]]$branchNames
  )

  # Local function.
  Function Push {
    (& $gitExe push) | Write-Host
    if ($LASTEXITCODE) {
      throw "Failed when trying to push local commits (Exit code $LASTEXITCODE)."
    }
  }

  if ($null -ne $branchNames) {
    foreach ($b in $branchNames) {
      (& $gitExe checkout $b) | Write-Host
      Push
    }
  }
  else {
    Push
  }
}

Function Start-GitReleaseBranch {
  [CmdletBinding()]
  Param([String]$gitExe, [String]$releaseName)

  (& $gitExe flow release start $releaseName) | Write-Host
  if ($LASTEXITCODE) {
    throw "Could not start git flow release."
  }
}

Function Write-VersionNumber {
  [CmdletBinding()]
  Param([Int]$major, [Int]$minor, [Int]$patch, [String]$releaseName)

  $path = (Get-ChildItem -Recurse -Include RmGetOpts.cpp | Select-Object -First 1).FullName
  $content = Get-Content $path

  # Write the updated source containing version numbers to file
  $content `
    -replace "VersionMajor\s*?=\s*?\d+?\s*?;", "VersionMajor = $major;" `
    -replace "VersionMinor\s*?=\s*?\d+?\s*?;", "VersionMinor = $minor;" `
    -replace "VersionPatch\s*?=\s*?\d+?\s*?;", "VersionPatch = $patch;" `
    | Out-File $path -Encoding ASCII
  if ($LASTEXITCODE) {
    throw "Could not write updated version number."
  }
}

Function Save-VersionNumberCommit {
  [CmdletBinding()]
  Param([String]$gitExe, [String]$versionString)
  (& $gitExe commit -a -m ("Bumped version number to v" + $versionString + ".")) | Write-Host
  if ($LASTEXITCODE) {
    throw "Could not commit changes."
  }
}

Function Complete-GitReleaseBranch {
  [CmdletBinding()]
  Param([String]$gitExe, [String]$versionString)
  (& $gitExe flow release finish $versionString -m $releaseNotes) | Write-Host
  if ($LASTEXITCODE) {
    throw "Could not finish git flow release."
  }
}

Function Invoke-Build {
  Push-Location ..\code\tools\build
  try {
    ./Build.ps1 Release
    $e = $LASTEXITCODE
    if ($e) {
      throw "Build reported an error: $e"
    }
  }
  finally {
    Pop-Location
  }
}

Function Set-ReleaseExecutableSignature {
  Write-Host "Signing ROOTMAP executable with certificate..."
  if (-Not (Test-Path  ../build/Win32_r/RootMap.exe)) {
    throw "Release build of RootMap.exe not found."
  }
  $signtool = 'signtool'
  try {
    & $signtool | Out-Null # Attempt to use the version of signtool.exe on the PATH
  }
  catch {
    # If we can't find a version of signtool on the path, take a reasonable guess.
    # TODO: Make this more robust.
    $signtool = "$Env:programfiles (x86)\Windows Kits\10\bin\x64\signtool.exe"
  }
  & $signtool sign /v /f FakeSPC.pfx /tr http://timestamp.globalsign.com/?signature=sha2 /td sha256 ../build/Win32_r/RootMap.exe
  if ($LASTEXITCODE) {
    throw "Signing RootMap.exe failed."
  }
}

Function Invoke-InstallerBuild {
  [CmdletBinding()]
  Param([String]$versionString)
  Write-Host "Invoking makensis.exe to build ROOTMAP installer..."
  & "$Env:programfiles (x86)\NSIS\makensis.exe" /DVERSION=$versionString InstallROOTMAP.nsi
  if ($LASTEXITCODE) {
    throw "Building the ROOTMAP Windows installer failed."
  }
}

Function Invoke-BuildAppAndInstaller {
  [CmdletBinding()]
  Param([String]$versionString)

  Invoke-Build
  Set-ReleaseExecutableSignature

  Invoke-InstallerBuild $versionString

  # TODO: fingerprint the installer, write the fingerprint to file or some such,
  # think about where to host installers
}


###################################################################################################


####################################
# Begin release generation script. #
####################################

$versionNumberArray = Get-CurrentVersionNumber

$versionString = $versionNumberArray -join '.'

Write-Host ('v' + $versionString)

# Tests.
# Write-Host ('Testing args', 'eyyy', 'woooo', 'heyyyy')
# Test-Args ('eyyy', 'woooo', 'heyyyy')
# Write-Host ('Testing args', 'major', 'notes notes notes')
# Test-Args ('major', 'notes notes notes')
# Write-Host ('Testing args', 'minor', 'notes notes notes')
# Test-Args ('minor', 'notes notes notes')
# Write-Host ('Testing args', 'patch', 'notes notes notes')
# Test-Args ('patch', 'notes notes notes')
# Write-Host ('Testing args', 'explicit', 'notes notes notes')
# Test-Args ('explicit', 'notes notes notes')
# Write-Host ('Testing args', 'explicit', 'notes notes notes', '1.2.3')
# Test-Args ('explicit', 'notes notes notes', '1.2.3')
# Write-Host ('Testing args', 'explicit', '1.2.3', 'notes notes notes')
# Test-Args ('explicit', '1.2.3', 'notes notes notes')

$git = Get-GitExe

Write-Host $git

Receive-GitRemoteCommits $git
Send-GitLocalCommits $git

# is there an equivalent of the `using()` idiom in Powershell?
Start-GitReleaseBranch $git $versionString # If anything breaks after this point, we need to delete the release branch.
Write-VersionNumber $versionNumberArray

Save-VersionNumberCommit $git $versionString

Complete-GitReleaseBranch $git $versionString

Send-GitLocalCommits $git 'master' 'develop' # Ensure all local changes are pushed to origin
Receive-GitRemoteCommits $git 'master' # Get any other changes that may have appeared on master, before the build

# TODO get Azure Devops to take over this functionality.
#Invoke-BuildAppAndInstaller $versionString

###################################################################################################

Write-Host "Successfully created ROOTMAP release v$versionString."
