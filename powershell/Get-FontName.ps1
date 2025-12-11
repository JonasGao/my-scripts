$path        = 'A:\segoescb.ttf'
$folder      = Split-Path $path
$file        = Split-Path $path -Leaf

$shell       = New-Object -COMObject Shell.Application
$shellfolder = $shell.Namespace($folder)
$shellfile   = $shellfolder.ParseName($file)

## get (localized) description and value of 
##   specified extended attributes numbers
## (0,2,21,165,166,195) 

(0,1,2,3,4,5,6,9,10,19,21,25,33,34,58,62,165,166,167,170,191,192,193,195,197,203,255)| 
Foreach-Object { 
    '{0,3} {1,-30} = {2}' -f $_,
            $shellfolder.GetDetailsOf($null, $_), 
            $shellfolder.GetDetailsOf($shellfile, $_) 
}