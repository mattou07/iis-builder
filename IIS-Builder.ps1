param ([string]$path)

$script = $myinvocation.mycommand.definition
$dir = Split-Path $MyInvocation.MyCommand.Path
Write-Host "Script location $script"
Write-Host "Script started in $dir"

if((![string]::IsNullOrWhiteSpace($path))) {
    if((Test-Path $path)){
        if([System.IO.Path]::IsPathRooted($path)){
            $dir = $path
        }
        else {
            $dir = Resolve-Path -Path $path
        }
        Write-Host "Path has been supplied passing in: $dir as working directory"
    }
    else {
        Write-Host "Unable to locate $path please provide a valid path"
        exit
    }
}

if ((Test-Path "$dir\iis-config.json") -eq $false){
    Write-Host "Could not find iis-config.json in $dir"
    exit
}

#Ensure our script is elevated to Admin permissions
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "Script has been opened without Admin permissions, attempting to restart as admin"
    $arguments = "-noexit & '" + $script + "'","-path $dir"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}
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

function assignUmbracoFolderPermissions($dir, $iisAppPoolName){
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
}

#verification helpers
function checkSiteExisiting($iisAppName){
    $exists = $false
    if(Get-Website -Name "$iisAppName"){
        $exists = $true
    }
    return $exists
}

function checkAppPoolExists($iisAppPool){
    #check if the app pool exists
    return (Test-Path IIS:\AppPools\$iisAppPool -pathType container)
}

#Buggy still - not in use
function getExisitingIISBindings($iisAppName){
    return Get-IISSiteBinding -Name $iisAppName
}

function getSiteStatus($iis){
    $exists = checkSiteExisiting($iis.siteName)
    if($exists){
        $status = [pscustomobject]@{
            siteExists = $exists
            appPoolExists = checkAppPoolExists($iis.appPoolName)
            #bindings = getExisitingIISBindings($iis.siteName)
        }
    }
    else {
        $status = [pscustomobject]@{
            siteExists = $exists
            appPoolExists = checkAppPoolExists($iis.appPoolName)
            bindings = $false
        }
    }
    
    return $status
}

function createAppPool($appPoolName, $runtimeVersion){
    #create the app pool
    $appPool = New-WebAppPool $appPoolName
    $appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $runtimeVersion
}

function createSite($iis){
    #Assign http bindings
    $i = 0
    foreach ($binding in $iis.siteBindings){
        if($i -eq 0){
            New-Website -Name $iis.siteName -PhysicalPath $iis.dir -ApplicationPool $iis.appPoolName -HostHeader $binding
        }
        else {
            New-WebBinding -Name $iis.siteName -IPAddress "*" -Port 80 -HostHeader $binding
        }
        $i++
    }
}

function identifyLatestCertificate($certs){ 
    Write-Host $certs.count " Certificates found for $binding identifying latest"
    $latest = ""
    foreach ($cert in $certs){
        if($latest -eq ""){
            #Load our first cert into latest
            $latest = $cert
        }
        else {
            if($latest.NotAfter -lt $cert.NotAfter){
                #if latest expiry is before the next cert replace latest
                $latest = $cert
            }
        }
    }
    return $latest
}

function deleteCerts($certs){
    foreach ($cert in $certs){
        Remove-Item -LiteralPath $cert.PSPath
        Write-Host "Deleted redundant cert with Thumbprint" $cert.Thumbprint
    }
}

function createCert($binding){
    $newCert = New-SelfSignedCertificate -DnsName "$binding" -CertStoreLocation "cert:\LocalMachine\My"
    Write-Host "Created new certificate with Thumbprint" $newCert.Thumbprint
    return $newCert
}

function rationaliseCerts($binding){
    $certs = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$binding"}
    Write-Host "Checking for existing certificate"
    if($certs){
        #Identify and remove multiple certificates
        if($certs.count -gt 1){
            $latestCert = identifyLatestCertificate($certs)
            $redundantCerts = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$binding" -and $_.Thumbprint -ne $latestCert.Thumbprint}
            deleteCerts($redundantCerts)
            
            #WARNING! The code below will delete expired certs from your trusted certificate store enable at your own risk.
            #Check if cert is in trusted store and remove it

            # $redundantRootCerts = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -eq "CN=$binding" -and $_.Thumbprint -ne $latestCert.Thumbprint}
            # Write-Host "Found " $redundantRootCerts.count "redundant Trusted Root certs for " $binding
            # deleteCerts($redundantRootCerts)
        }

        #Attempt to get the certificate
        $cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$binding"}
        Write-Host "Found " $cert.count "certificates using the CNAME of " $binding
        Write-Host "Found Cert expires on" $cert.NotAfter 
        #Check if the certificate is close to expiry
        if($cert.NotAfter -le (Get-Date).AddDays(30)){
            Write-Host "Certificate will expire in less than 30 days, renewing..."
            deleteCerts($cert)
            $cert = createCert($binding)
            
        }
        
    }
    else {
        #No certificate was found
        Write-Host "No certificate was found creating one.."
        $cert = createCert($binding)
    }

    return $cert
}

#Bindings need to be organised before they are added
function ensureSSL($iis){
    # # Assign certificates to https bindings
    foreach ($binding in $iis.siteBindings){
        #create a https binding
        #Check if certificate exists, create a new self cert if it doesn't
        Write-Host "Ensuring Certificate for $binding"
        $cert = rationaliseCerts($binding)
        Write-Host "Rationalised Thumbprint " $cert.Thumbprint
        $cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$binding"}
        Write-Host "Picked Cert after search " $cert.Thumbprint
        New-WebBinding -Name $iis.siteName -Protocol "https" -Port 443 -IPAddress * -HostHeader $binding -SslFlags 1
        
        #Check if certificate already exisits in trusted certificates
        if(!(Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Thumbprint -eq $cert.Thumbprint})){
            
            Write-Host "Certificate is not in trusted store. Adding..."
            $DestStore = new-object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,"localmachine"
        )
        
        $DestStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $DestStore.Add($cert)
        $DestStore.Close()
        }    
        #Using netsh to assign the ssl certs to the binding. powershell cmdlets seem to add certificates to all https bindings in the web site, not ideal
        (Get-WebBinding -Name $iis.siteName -Port 443 -Protocol "https" -HostHeader $binding).AddSslCertificate($cert.Thumbprint, "my")
    }
}

# ============== Start Script
Import-Module WebAdministration
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
Write-Host "Starting in $dir"
#Load JSON
$iisconfig = Get-Content  "$dir\iis-config.json" | Out-String | ConvertFrom-Json

$iis = [pscustomobject]@{
    siteName = $iisconfig."IIS-Site-Name"
    appPoolName = $iisconfig."App-Pool-Name"
    siteBindings = $iisconfig."bindings"
    dir = $dir
    dotNetVersion = $iisconfig."IIS-App-Pool-Dot-Net-Version"
    }
Write-Host "Loaded in JSON"
#Obtain current status of site
$status = getSiteStatus($iis)

# Create App pool if it doesn't exist
if(!$status.appPoolExists){
    createAppPool $iis.appPoolName $iis.dotNetVersion
}
Write-Host "Ensured App Pool"
#Easier to remove the IIS site and re create it than editing the bindings
if($status.siteExists){
    Remove-WebSite -Name $iis.siteName
    Write-Host "Site already exists - Removing..."
}

#Create our IIS site which will add both http and https bindings
Write-Host "Creating IIS Site"
createSite $iis
Write-Host "Assigning folder permissions on Web Root"
assignUmbracoFolderPermissions $iis.dir $iis.appPoolName
Write-Host "Ensuring SSL"
ensureSSL $iis

Write-Host "Adding non localtest.me domains to hosts file"
# #Add bindings to hosts file
foreach ($binding in $iis.siteBindings){
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

Write-Host "Bindings added"
foreach ($binding in $iis.siteBindings){
    Write-Host "$binding"
}

Write-Host "Done, thanks for using IIS Builder"