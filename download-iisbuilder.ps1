#Get list of issbuilder tags
$githubApi = "https://api.github.com/repos/mattou07/iis-builder/tags"

#Obtain tag data from github api
$data = Invoke-RestMethod -Uri $githubApi

$downloadedScript = $false
if((Test-Path ".\IIS-Builder.ps1" -PathType Leaf) -eq $false){
    Write-Host "IIS-Builder not found in folder downloading based on latest tag: $($data.Name[0])"
    Write-Host "Downloading IIS Builder from: $($data.zipball_url[0])"
    Invoke-WebRequest -Uri $($data.zipball_url[0]) -Outfile "iis-builder-$($data.Name[0]).zip"
    Write-Host "Extracting..."
    Expand-Archive "iis-builder-$($data.Name[0]).zip" -DestinationPath "iis-builder"
    $iisBuilderPath = Get-ChildItem -Path "iis-builder/" -Force -Recurse -File | Where-Object {$_.Name -eq "IIS-Builder.ps1"}
    $iisJsonPath = Get-ChildItem -Path "iis-builder/" -Force -Recurse -File | Where-Object {$_.Name -eq "iis-config.json"}
    Write-Host "Adding IISBuilder to current directory $(Get-Location)"
    Move-Item -Path $iisBuilderPath.FullName -Destination "$(Get-Location)"
    
    if((Test-Path ".\iis-config.json" -PathType Leaf) -eq $false){
        Write-Host "iis-config.json is missing... Grabing template from zip"
        Move-Item -Path $iisJsonPath.FullName -Destination "$(Get-Location)"
        Write-Host "PLEASE ENSURE YOU UPDATE THE iis-config.json WITH YOUR DESIRED NAMES BEFORE YOU RUN IIS-Builder.ps1"
    }
    else {
        Write-Host "iis-config.json already exists not copying from zip"
    }
    Write-Host "Cleaning up..."
    Remove-Item ".\iis-builder" -Recurse
    Remove-Item "iis-builder-$($data.Name[0]).zip"
}
else{
    Write-Host "IIS-Builder.ps1 already exists please delete it to get the latest version"
}