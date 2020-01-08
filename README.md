# IIS-Builder




## Overview

Automate your local IIS Development Environment with this script, its designed to build a development IIS site for your project.

## Quick Start

The easiest way to download IIS builder is to just use the two powershell commands below inside your web root. 

```powershell
(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mattou07/iis-builder/master/IIS-Builder.ps1','IIS-Builder.ps1')

(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mattou07/iis-builder/master/iis-config.json','iis-config.json')
```
The two commands will use System.Net.WebClient to download the needed files. Similar to wget in linux.

Here is a gif demonstrating the process:

![Gif demonstrating how to download the script and JSON](https://i.imgur.com/9FCteS0.gif)

Open the JSON file and edit the contents to set the **Site name**, **App Pool name** and **bindings**. You can leave the dot net version as the default value.

```json
{
  "IIS-Site-Name": "test-site",
  "App-Pool-Name": "test-site",
  "IIS-App-Pool-Dot-Net-Version": "v4.0",
  "bindings": ["test-site.localtest.me"]
}
```

- IIS-Site-Name should be the name of the IIS site
- App-Pool-Name is the name of the App Pool for the site, ideally this should be the same as the IIS Site Name
- Bindings is a comma separated list, you can specify multiple bindings and the script will add both a HTTP and HTTPS binding to your IIS site

Then run the script by right clicking the **IIS-Builder.ps1** file and clicking **Run with Powershell** or typing **.\IIS-Builder.ps1** inside powershell if its open in your web root. 

No need to open an eleveted powershell session it will open its own elevated session.

## Additional tips

### Attaching script to Visual Studio Post build event

This script can be setup as a post build event in Visual Studio, so every time you build the project the script will run.

To set this up right click on the web project and click properties.

![Web Project Properties](https://i.imgur.com/wzzS8tE.png)

Head to the Build events section and in the Post-build event command line add this:

`%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Unrestricted -file $(ProjectDir)\IIS-Builder.ps1`

![Build Events](https://i.imgur.com/PUGiiP7.png)

#### What this command means

`%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe`

We fetch the location of your Windows Powershell exe. Some users may not have it in the same place so using: **%SystemRoot%\sysnative** should allow it to work on most windows machines.

`-ExecutionPolicy Unrestricted`

Since this script is being downloaded from the internet powershell will automatically block it. Setting the Execution Policy to Unrestricted will allow you run the script without having to create your own Powershell file and copy the code and save.

`-file $(ProjectDir)\IIS-Builder.ps1`

We then specify that the powershell script is in the same directory as the web project being built using $(ProjectDir).

### Would you like the browser to open the website automatically after running the script?

Uncomment line 201. This is commented out by default as it can get annoying.

## What the script does

First the script needs admin privileges so it will attempt to start an elevated powershell process. It then pulls in the properties defined in the json for the site that needs to be built. Using those properties it checks to see if an IIS site already exists. If a site already exists with the name, it will be removed. App pools will not be removed if they already exist.

Next the script will create an IIS site and App pool using the details defined in the json. We then need to setup the bindings. The script allows you to define multiple urls in an array in the json. First the script adds the HTTP bindings as that is straightforward to do.

Now we need to setup the HTTPS bindings, first we create a New-SelfSignedCertificate for each binding and set the Dns name to be the one of the bindings we have defined in the json. Now that we have a certificate created we can create the binding for the IIS site.

The next part will take our newly created certificates and assign it to our bindings. For the certificates to be trusted by the browser we add it to the Root directory of the local machine.

We then need to setup the correct file permissions on the folder. This was primarily setup for Umbraco you may want to enforce stricter permissions or assign other entities to meet your requirements.

We give the following entities Modify permissions on the web root:

- IUSR
- IIS_IUSRS
- App Pool Identity (As defined in the iis-config.json)

We then loop through the bindings and if they don't contain .localtest.me they are not added to the hosts file. Domains ending with .localtest.me automatically point to 127.0.0.1 therefore its not needed in the hosts file.

Please raise an issue if something is not working as expected!

Made with :heart: at [Moriyama](https://www.moriyama.co.uk/)

[My devops focused blog](https://mu7.dev)
