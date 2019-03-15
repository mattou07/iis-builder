# IIS-Builder

## Overview

Automate your local IIS Development Environment with this script, its designed to build a development IIS site for your project.

## How to use

Place me into the web root of your site and fill in the details about you local IIS site. In the iis-config.json

`{

​    "IIS-Site-Name": "test-site",

​    "App-Pool-Name": "test-site",

​    "IIS-App-Pool-Dot-Net-Version": "v4.0",

​    "bindings": ["test-site.localtest.me"]

}`

- IIS-Site-Name should be the name of the IIS site
- App-Pool-Name is the name of the App Pool for the site, ideally this should be the same as the IIS Site Name
- Bindings is a comma separated list, you can specify multiple bindings and the script will add them to your IIS site bindings

Now just run the script and it will attempt to build the site for you. If a IIS site with the same name already exists it will open that site in your browser and the script will exit.

## Attaching script to Visual Studio Post build event

This script can be setup as a post build event in Visual Studio, so every time you build the project the script will run.

To set this up right click on the web project and click properties.

![Web Project Properties](https://i.imgur.com/wzzS8tE.png)

Head to the Build events section and in the Post-build event command line add this:

`%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Unrestricted -file $(ProjectDir)\IIS-Builder.ps1`

![Build Events](https://i.imgur.com/PUGiiP7.png)

### What this command means

**`%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe`**

We fetch the location of your Windows Powershell exe. Some users may not have it in the same place so using: **%SystemRoot%\sysnative** should allow it to work on most windows machines.

**`-ExecutionPolicy Unrestricted`**

Since this script is being downloaded from the internet powershell will automatically block it. Setting the Execution Policy to Unrestricted will allow you run the script without having to create your own Powershell file and copy the code and save.

`**-file $(ProjectDir)\IIS-Builder.ps1**`

We then specify that the powershell script is in the same directory as the web project being built using $(ProjectDir).

## What the script does

First the script needs admin privileges so it will attempt to start an elevated powershell process. It then pulls in the properties defined in the json for the site that needs to be built. Using those properties it checks to make sure that the IIS site the user wants to create doesn’t exist already.

Next the script will create an IIS site and App pool using the details defined in the json. We then need to setup the bindings. The script allows you to define multiple urls in an array in the json. First the script adds the HTTP bindings as that is straightforward to do.

Now we need to setup the HTTPS bindings, first we create a New-SelfSignedCertificate for each binding and set the Dns name to be the one of the bindings we have defined in the json. Now that we have a certificate created we can create the binding for the IIS site.

The next part will take our newly created certificates and assign it to our bindings using a netsh command. For the certificates to be trusted by the browser we add it to the Root directory of the local machine.

We then need to setup the correct file permissions on the folder. This was primarily setup for Umbraco you may want to enforce stricter permissions on your local site for testing.

We give the following entities Modify permissions on the web root:

- IUSR
- IIS_IUSRS
- App Pool Identity (As defined in the iis-config.json)

We then loop through the bindings and if they don't contain .localtest.me they are not added to the hosts file. Domains ending with .localtest.me automatically point to itself therefore its not needed in the hosts file.

Made with :heart: at [Moriyama](https://www.moriyama.co.uk/)