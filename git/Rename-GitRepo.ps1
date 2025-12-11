[CmdletBinding()]
param(
  [string]$Target,
  [string]$Base = "$HOME"
)

function Move-GitRepo() {
  [CmdletBinding()]
  param(
    [System.IO.DirectoryInfo]$Target,
    [string]$AbsParentPath
  )
  Write-Verbose ("Target parent path: [{0}]" -f $AbsParentPath)
  if (-not (Test-Path $AbsParentPath)) {
    New-Item $AbsParentPath -Force -ItemType Directory
  }
  Move-Item $Target.FullName $AbsParentPath
  $absTargetPath = (Join-Path $AbsParentPath $Target.Name)
  Write-Output ("{0} <- {1}" -f (Test-Path $absTargetPath), $absTargetPath)
}

Write-Verbose ("Rename working on [{0}]" -f $Target)
Get-ChildItem $Target -Directory | ForEach-Object {

  Write-Verbose ("Testing on [{0}]" -f $_.FullName)
  Write-Debug (Test-Path (Join-Path $_.FullName ".git") -PathType Container)

  if (Test-Path (Join-Path $_.FullName ".git") -PathType Container) {

    Write-Verbose ("Get git remote [{0}]" -f $_.FullName)

    Push-Location $_.FullName
    $remoteUrl = (git config --get remote.origin.url)
    Pop-Location

    if (-not $remoteUrl) {
      Write-Output ("'{0}' no remote" -f $_.FullName)
      return
    }

    if ($remoteUrl -match "^git@(.+?):(.+?)/.+?\.git$") {
      Write-Verbose ("Git matched for [{0}]" -f $remoteUrl)
      Move-GitRepo -Target $_ -AbsParentPath (Join-Path $Base $Matches[1] $Matches[2])
      return 
    }

    if ($remoteUrl -match "^https://(.+)/.+?\.git") {
      Write-Verbose ("Https matched for [{0}] `n`n {1}" -f $remoteUrl, ($Matches | Out-String))
      Move-GitRepo -Target $_ -AbsParentPath (Join-Path $Base $Matches[1])
      return 
    }
  }
}
