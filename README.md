# IIS-Builder




## Overview

Automate your local IIS Development Environment with this script, its designed to build a development IIS site for your project.

This script does **NOT** support 32-Bit Windows.

## New features for 1.3.0

As of 1.3.0 you can now provide a path to the script using the **-Path** argument.

Since this is a minor update this means the new version is still backwards compatible with projects that have been using previous versions of IIS Builder. 

If you are finding issues with this update you can download the previous versions from the [tags](https://github.com/mattou07/iis-builder/tags) page.




## Quick Start

The easiest way to download IIS builder is to just use the two Powershell commands below. 

As of v1.3.0 this command doesn't need to be ran within the web root as we can now supply a **-Path** argument. However feel free to download into the web root of your project if that is preferred. 

```powershell
(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mattou07/iis-builder/master/IIS-Builder.ps1','IIS-Builder.ps1')
```
The next command which downloads the JSON file **MUST** be ran inside your web root and committed into source control. This will allow others to share the same domains and enforce your best practices for your local domains on a project.
```powershell
(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mattou07/iis-builder/master/iis-config.json','iis-config.json')
```
The two commands will use **System.Net.WebClient** to download the needed files. Similar to wget in linux.

Here is a gif demonstrating the process:

![Gif demonstrating how to download the script and JSON](https://i.imgur.com/9FCteS0.gif)

We now need to configure the domains we will be using for our IIS Site. Open the JSON file and edit the contents to set the **Site name**, **App Pool name** and **bindings**. You can leave the dot net version as the default value.

```json
{
  "IIS-Site-Name": "test-site",
  "App-Pool-Name": "test-site",
  "IIS-App-Pool-Dot-Net-Version": "v4.0",
  "bindings": ["test-site.localtest.me"]
}
```

- IIS-Site-Name should be the name of the IIS site **my-awesome-site**
- App-Pool-Name is the name of the App Pool for the site, ideally this should be the same as the IIS Site Name
- Bindings is a comma separated list, you can specify **multiple bindings** and the script will add both a **HTTP** and **HTTPS** for each binding to your IIS site
- **HTTPS** is provided by a self signed certificate

Then run the script by right clicking the **IIS-Builder.ps1** file and clicking **Run with Powershell** or typing **.\IIS-Builder.ps1** inside powershell if its open in your web root. 

No need to open an eleveted powershell session it will open its own elevated session.

### As of update v1.3.0

You can now supply a -**path** argument into the script instead of explicitly storing the script within your web root. 

C:\dev\github\iis-builder\IIS-Builder.ps1 **-Path "D:\dev\my-website\web-root"**

Below I setup a local IIS Site for my blog, the script and the web root are not in the same folder anymore.

![Supplying a -Path argument to IIS Builder](https://i.imgur.com/ZOzNtnK.gif)

### Running IIS Builder as an external tool in Visual Studio with v1.3.0

We can take this further and streamline the process with **Visual Studio's External tools** feature. Below I run IIS Builder within Visual Studio without needing to look for the Powershell script on my machine or open the web root folder. Simply **click** on the web project **containing the iis-config.json file** and then run the external tool (**YOU MUST SELECT THE WEB PROJECT BEFORE RUNNING**)

Below you can see the process to run an external tool. Simply click it from your menu and then start hacking away in seconds:

![Running IIS Builder as an external tool](https://i.imgur.com/nadG9Dp.gif)

### Setting up the external tool

In Visual Studio go to **Tools > External Tools...**

![Location of External tools in Visual Studio](https://i.imgur.com/7evwBQ5.png)

Then fill out the details: 

![Image showing filled out details for IIS Builder as an External Tool](https://i.imgur.com/aDRRgMa.png)



**Title** can be whatever you wish. I named mine IIS Builder

**Command** should be: **%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe** or wherever your 64 bit version of Powershell lives. This should work on all 64 bit machines.

**Arguments** should be the location of the IIS Builder script: **C:\location\of\script\IIS-Builder.ps1 -Path $(ProjectDir)**. Ensure you add the **-Path $(ProjectDir)** argument on the end. This allows you to tell IIS Builder where your web project lives. Ensure you provide the correct path for where IIS Builder lives.

Nothing needs to be supplied into Initial directory.

Ensure **Use Output window** is **enabled** this will allow you to see the output of IIS Builder within Visual Studio.

To prevent IIS Builder popping up an Elevated Powershell Window, open Visual Studio as Admin. However this is not necessary.

### Setup a Powershell Alias

If you love using the terminal you could setup a Powershell Alias. Where all you need to do is navigate to your folder via Powershell and type **IISBuilder** or whatever alias/shortcut you prefer. This then runs IIS-Builder.ps1 in your current working directory:

![Running IISBuilder as a Powershell Alias](https://i.imgur.com/jN0SiDp.png)

To set this up you need to identify where your Powershell user profile lives, by typing:  `echo $profile` 

This will reveal where Powershell thinks the User profile lives. Usually its **~Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1**. Adding any code within this file will be executed on each Powershell session for your User. When you set an Alias its forgotten when you close the Powershell session. By setting our alias in our profile, Powershell will create the alias each time we start a Powershell Session 

Navigate to your profile location and open the **Microsoft.PowerShell_profile.ps1** file. If it doesn't exist **create** it. Then add the following code to setup the alias:

```powershell
Function IISBuilderFunc {C:\your-path-to-iisbuilder\IIS-Builder.ps1 -Path $(Get-Location)}

Set-Alias -Name IISBuilder -Value IISBuilderFunc
```

Make sure to provide the correct path to where the IIS-Builder.ps1 file lives. Feel free to change the Alias name to whatever you wish or even rename the function. These two lines tell Powershell to create an Alias called IISBuilder that triggers the function IISBuilderFunc above. The function just calls the IISBuilder script file and passes in the current location of the terminal as the **-Path** parameter allowing you to run the alias anywhere.

Save the file and re-open a Powershell Terminal, then navigate to your web root and type IISBuilder.

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
