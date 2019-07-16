# Ensure our script is elevated to Admin permissions
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "-noexit & '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

Import-Module WebAdministration
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
# Grab the json config file
$iisconfig = Get-Content  "$dir\iis-config.json" | Out-String | ConvertFrom-Json
$iisAppPoolName = $iisconfig."IIS-Site-Name"
$iisAppPoolDotNetVersion = $iisconfig."IIS-App-Pool-Dot-Net-Version"
$iisAppName = $iisconfig."App-Pool-Name"
$siteBinding = $iisconfig."bindings"
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"

# Known limitations:
# - does not handle entries with comments afterwards ("<ip>    <host>    # comment")
# https://stackoverflow.com/questions/2602460/powershell-to-manipulate-host-file
#
function add-host([string]$filename, [string]$ip, [string]$hostname) {
    remove-host $filename $hostname
    $ip + "`t`t" + $hostname | Out-File -encoding ASCII -append $filename
}

function remove-host([string]$filename, [string]$hostname) {
    $c = Get-Content $filename
    $newLines = @()

    foreach ($line in $c) {
        $bits = [regex]::Split($line, "\t+")
        if ($bits.count -eq 2) {
            if ($bits[1] -ne $hostname) {
                $newLines += $line
            }
        } else {
            $newLines += $line
        }
    }

    # Write file
    Clear-Content $filename
    foreach ($line in $newLines) {
        $line | Out-File -encoding ASCII -append $filename
    }
}

#verify the site exists before progressing

if(Get-Website -Name "$iisAppName"){
    #Add bindings to hosts file
    foreach ($binding in $siteBinding){
    #Look for .localtest.me domain
    #if the domain is .localtest.me don't create a entry in the hosts file
        if(-Not ($binding -Match"https://") -or -Not ($binding -Match"http://")){
            $binding = "https://$binding"
        }

        #Enable me if you would like the browser to automatically open when the script is ran
        #Start-Process $binding
    }
    exit
}

#navigate to the app pools root
Set-Location IIS:\AppPools\

#check if the app pool exists
if (!(Test-Path $iisAppPoolName -pathType container))
{
    #create the app pool
    $appPool = New-Item $iisAppPoolName
    $appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $iisAppPoolDotNetVersion
}

#navigate to the sites root
Set-Location IIS:\Sites\

#check if the site exists
if (Test-Path $iisAppName -pathType container)
{
    return
}


# create array with http bindings
$IISBindingArr = @()

foreach ($binding in $siteBinding){
    $IISBindingArr+= @{protocol="http";bindingInformation=":80:" + $binding}
}
#create the site and assign http bindings
$iisApp = New-Item $iisAppName -bindings $IISBindingArr -physicalPath $dir
$iisApp | Set-ItemProperty -Name "applicationPool" -Value $iisAppPoolName

# Assign certificates to https bindings
foreach ($binding in $siteBinding){
    #create a https binding
    if(!(Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$binding"})){
        New-SelfSignedCertificate -DnsName "$binding" -CertStoreLocation "cert:\LocalMachine\My"
    }
    New-WebBinding -Name $iisAppName -Protocol "https" -Port 443 -IPAddress * -HostHeader $binding -SslFlags 1
	

	$Thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$binding"}).Thumbprint;
    $cert = ( Get-ChildItem -Path "cert:\LocalMachine\My\$Thumbprint" )

    #Check if certificate already exisits in trusted certificates
    if(!(Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Thumbprint -eq $Thumbprint})){
        $DestStore = new-object System.Security.Cryptography.X509Certificates.X509Store(
		[System.Security.Cryptography.X509Certificates.StoreName]::Root,"localmachine"
	)
    

	$DestStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
	$DestStore.Add($cert)
    $DestStore.Close()
    }

	
    
    #Using netsh to assign the ssl certs to the binding. powershell cmdlets seem to add certificates to all https bindings in the web site, not ideal
    Invoke-Expression "netsh http add sslcert hostnameport=$($binding):$(443) certhash=$Thumbprint appid='{4dc3e181-e14b-4a21-b022-59fc669b0914}' certstorename=MY"
}
#Assign Umbraco IIS permissions to parent folder
Write-Host $dir
$Acl = Get-Acl $dir
$Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("IUSR","Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
$Acl.SetAccessRule($Ar)
Set-Acl -Path $dir -AclObject $Acl

$Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("IIS_IUSRS","Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
$Acl.SetAccessRule($Ar)
Set-Acl -Path $dir -AclObject $Acl

$iisAppPoolName = "IIS apppool\$iisAppPoolName"
$Ar = New-Object  system.security.accesscontrol.filesystemaccessrule($iisAppPoolName,"Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
$Acl.SetAccessRule($Ar)
Set-Acl -Path $dir -AclObject $Acl

#Add bindings to hosts file
foreach ($binding in $siteBinding){
    #Look for .localtest.me domain
    #if the domain is .localtest.me don't create a entry in the hosts file
    if(-Not ($binding -Match"localtest.me")){
        add-host $hostsPath "127.0.0.1" $binding
    }
    if(-Not ($binding -Match"https://") -or -Not ($binding -Match"http://")){
        $binding = "https://$binding"
    }

    #Enable me if you would like the browser to automatically open when the script is ran
    #Start-Process $binding
}