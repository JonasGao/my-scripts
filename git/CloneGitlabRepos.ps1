[CmdletBinding()]
param(
  $Token,
  $GitLab,
  $Size = 10,
  [Switch]$Dry = $False
)
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Private-Token", "$Token")
$has_groups = $True
$groups_page = 1
while($has_groups)
{
  $groups_response = Invoke-WebRequest "https://$GitLab/api/v4/groups?per_page=$Size&page=$groups_page" -Method 'GET' -Headers $headers
  $groups_content = $groups_response.Content
  $groups = $groups_content | ConvertFrom-Json
  $groups | ForEach-Object {
    $group_id = $_.id
    $group_name = $_.name
    Write-Verbose "Group -> $group_id, $group_name"
    if ( -not $Dry )
    {
      mkdir $group_name
      Push-Location $group_name
    }
    $has_projects = $True
    $projects_page = 1
    while($has_projects)
    {
      $projects_response = Invoke-WebRequest "https://$GitLab/api/v4/groups/$group_id/projects?per_page=$Size&page=$projects_page" -Method 'GET' -Headers $headers
      $projects_content = $projects_response.Content
      $projects = $projects_content | ConvertFrom-Json
      $projects | ForEach-Object {
        if ( -not $Dry )
        {
          git clone $_.ssh_url_to_repo
        } else
        {
          Write-Output $_.ssh_url_to_repo
        }
      }
      $projects_headers = $projects_response.Headers
      $projects_next_page = $projects_headers["X-Next-Page"]
      $projects_total_page = $projects_headers["X-Total-Pages"]
      Write-Verbose "Project Current: $projects_page"
      Write-Verbose "Project Next: $projects_next_page"
      Write-Verbose "Project Total: $projects_total_page"
      if ($projects_next_page -ne "" && $projects_next_page -lt $projects_total_page)
      {
        $projects_page = $projects_next_page
      } else
      {
        $has_projects = $False
      }
    }
    if ( -not $Dry )
    {
      Pop-Location
    }
  }
  $groups_headers = $groups_response.Headers
  $groups_next_page = $groups_headers["X-Next-Page"]
  $groups_total_page = $groups_headers["X-Total-Pages"]
  Write-Verbose "Group Current: $groups_page"
  Write-Verbose "Group Next: $groups_next_page"
  Write-Verbose "Group Total: $groups_total_page"
  if ($groups_next_page -ne "" && $groups_next_page -lt $groups_total_page)
  {
    $groups_page = $groups_next_page
  } else
  {
    $has_groups = $False
  }
}