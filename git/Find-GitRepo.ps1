param(
  [string]$Target
)

Get-ChildItem $Target -Directory | ForEach-Object {
  $gitDir = ("{0}\.git" -f $_.FullName)
  if (Test-Path $gitDir -PathType Container) {
    Push-Location $_
    Write-Output ("{0} -> {1}" -f $_.FullName, (git config --get remote.origin.url))
    Pop-Location
  }
}
