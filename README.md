# NanoServerPackage Provider
A PackageManagement (aka <a href="http://www.oneget.org">OneGet</a>) provider to find and install Optional Windows Packages (Windows feature and role) for Nano Server. For general information about these packages, please refer to the <a href="https://technet.microsoft.com/en-us/windows-server-docs/get-started/deploy-nano-server">guide on Deploy Nano Server</a>.

##### Note 
The public version 0.1.1.0 of NanoServerPackage Provider from the PowerShellGallery.com only supports Nano Server with Technical Preview 5 (TP5) version, i.e. 10.0.14300.1000, that is public in April 2016, and vice versa. It DOES NOT support Nano Server WS2016 GA version 10.0.14393.0. Please update your Nano Server to WS2016 GA version and install the latest version of the provider. 

## Installing the provider
To install the latest version of the provider 1.0.1.0 that works for WS2016 GA Nano Server 10.0.14393.0, use the following steps.
```
Save-Module -Path "$env:programfiles\WindowsPowerShell\Modules\" -Name NanoServerPackage -minimumVersion 1.0.1.0
Import-PackageProvider NanoServerPackage
```
To install the TP5 version of the provider 0.1.1.0 that works for TP5 OS version 10.0.14300.1000, use the following steps.
```
# Your Nano Server OS version is 10.0.14300.1000
Install-PackageProvider NanoServerPackage -requiredVersion 0.1.1.0
Import-PackageProvider NanoServerPackage
```

There are two sets of cmdlets provided in NanoServerPackage provider. The first set is specific to the provider:
```
Find-NanoServerPackage
Save-NanoServerPackage
Install-NanoServerPackage
```

The second set is generic PackageManagement cmdlets:
```
Find-Package
Save-Package
Install-Package
Get-Package
```

The provider needs to be loaded in PowerShell before you can use any of the cmdlets. You can load the provider  by running ```Import-PackageProvider NanoServerPackage```.

## Searching for Windows Packages

Both ```Find-NanoServerPackage``` and ```Find-Package``` search and return a list of Windows Packages available in the online repository. You may want to provide ```-ProviderName NanoServerPackage``` to ```Find-Package``` so that OneGet will not use other providers. In addition, when using the generic OneGet cmdlet, you can also use a ```-DisplayCulture``` switch so the culture of the packages will be displayed.

##### Example 1
Find the latest version of any Windows Packages that match a given name. Wildcard is also accepted
```
Find-NanoServerPackage -Name Microsoft-NanoServer-NPDS-Package
Find-NanoServerPackage -Name *NPDS*
```
OR
```
Find-Package -ProviderName NanoServerPackage -Name Microsoft-NanoServerPackage-NPDS-Package -DisplayCulture
Find-Package -ProviderName NanoServerPackage -Name *NPDS* -DisplayCulture
```

##### Example 2

Find the latest version of all available Windows Packages. The available cultures for each package are also displayed
```
Find-NanoServerPackage
```
OR
```
Find-Package -ProviderName NanoServerPackage -DisplayCulture
```

##### Example 3

Find the latest version of all available Windows Packages with culture en-us
```
Find-NanoServerPackage -Culture en-us
```
OR
```
Find-Package -ProviderName NanoServerPackage -Culture en-us -DisplayCulture
```


##### Example 4
Find Windows Packages that have a certain version using ```-RequiredVersion```
```
Find-NanoServerPackage -RequiredVersion 10.0.14393.0
```
OR
```
Find-Package -ProviderName NanoServerPackage -RequiredVersion 10.0.14393.0 -DisplayCulture
```

##### Example 5
Find Windows Packages within a certain version range using ```-MinimumVersion``` and ```-MaximumVersion```. The latest version of a package that satisfies the version range will be returned. For example, if the minimum version specified is 5.0, and the package have version 1.0, 5.0, 6.0 and 7.0, then the 7.0 version of the package will be returned.
```
Find-NanoServerPackage -MinimumVersion 10.0
```
OR
```
Find-Package -ProviderName NanoServerPackage -MinimumVersion 10.0 -DisplayCulture
```

##### Example 6
Find all available versions of a Windows Package using ```-AllVersions``` switch. This switch can also be used with ```-MinimumVersion``` and ```-MaximumVersion``` but not with ```-RequiredVersion```.
```
Find-NanoServerPackage *NPDS* -AllVersions
Find-NanoServerPackage *NPDS* -AllVersions -MinimumVersion 10.0
```
OR
```
Find-Package *NPDS* -ProviderName NanoServerPackage -AllVersions -DisplayCulture
Find-Package *NPDS* -ProviderName NanoServerPackage -AllVersions -DisplayCulture -MinimumVersion 10.0
```

## Installing Windows Packages Online or Offline
You can install a Windows Package (including its dependency packages, if any) using either ```Install-NanoServerPackage``` or ```Install-Package```. If you want to install the package to an offline NanoServer image, you can specify the path to the offline image with ```-ToVhd``` parameter. Otherwise, the cmdlets will install the package to the local machine.

Both cmdlets accept pipeline result from the search cmdlets. The culture of the package has to match the culture of the machine you are installing it to for the package to work properly. The cmdlets have auto-detection logic that will determine the suitable culture. 

##### Example 1
Installing the latest version of the Containers package to the local machine
```
Install-NanoServerPackage -Name Microsoft-NanoServer-Containers-Package
```
OR
```
Install-Package -ProviderName NanoServerPackage -Name Microsoft-NanoServer-Containers-Package -DisplayCulture
```

##### Example 2
Install a package that depends on other packages. In this case, the dependency packages will be installed as well.
```
Find-NanoServerPackage *scvmm-compute* | install-package
```

##### Example 3
Install the latest version of the DCB package to an offline NanoServer image.
```
Install-NanoServerPackage -Name Microsoft-NanoServer-DCB-Package -ToVhd C:\OfflineVhd.vhd
```
OR
```
Install-Package -Name Microsoft-NanoServer-DCB-Package -ToVhd C:\OfflineVhd.vhd -ProviderName NanoServerPackage -DisplayCulture
```

##### Example 4
Install the Containers package by piping the result from the search cmdlets. Please do not specify ```-ProviderName``` on the ```Install-Package``` cmdlet if you use it this way.
```
Find-NanoServerPackage *Containers* | Install-NanoServerPackage
```
OR
```
Find-Package -ProviderName NanoServerPackage *Containers* | Install-Package -DisplayCulture
```

## Dowloading Windows Packages
You can download a Windows Package (including its dependency packages, if any) without installing it by using ```Save-NanoServerPackage``` or ```Save-Package``` cmdlets. Both cmdlets accept pipeline result from the search cmdlets. These cmdlets will download both the base package and the language package. If you do not specify the ```-Culture``` parameter, the culture of the local machine will be used.

##### Example 1
Download and save the NPDS package to a directory that matches the wildcard path using the culture of the local machine.
```
Save-NanoServerPackage Microsoft-NanoServer-NPDS-Package -Path C:\t*p\
```
OR
```
Save-Package -ProviderName NanoServerPackage Microsoft-NanoServer-NPDS-Package -Path C:\t*p\ -DisplayCulture
```

##### Example 2
Download and save version 10.0.14393.0 of the NPDS package with de-de culture to the current directory.
```
Save-NanoServerPackage Microsoft-NanoServer-NPDS-Package -Path .\ -Culture de-de -RequiredVersion 10.0.14393.0
```
OR
```
Save-Package -ProviderName NanoServerPackage Microsoft-NanoServer-NPDS-Package -Path .\ -Culture de-de -RequiredVersion 10.0.14393.0 -DisplayCulture
```

##### Example 3
Download and save the it-it culture of the Shielded VM package to the current directory by piping the results from the search cmdlets. The dependency package will be downloaded as well.
```
Find-NanoServerPackage -Name *shielded* -Culture it-it | Save-NanoServerPackage -Path .\
```
OR
```
Find-Package -ProviderName NanoServerPackage *shielded* -Culture it-it | Save-Package -Path .\ -DisplayCulture
```

## Inventory what Windows Packages are installed
You can search for installed packages on your local NanoServer machine or an offline NanoServer image using ```Get-Package```.

##### Example 1
Search for all Windows Packages installed on the local machine.
```
Get-Package -ProviderName NanoServerPackage -DisplayCulture
```

##### Example 2
Search for all Windows Packages installed on an offline NanoServer image.
```
Get-Package -ProviderName NanoServerPackage -FromVhd C:\OfflineVhd.vhd -DisplayCulture
```

## Version
1.0.1.0

## Version History
#### 1.0.1.0
Public release for NanoServerPackage Provider that works for Nano Server WS2016 GA version 
#### 0.1.1.0
Initial public release for Nano Package Provider that works for TP5 Nano Server

### Dependencies
This module has no dependencies

## Known Issues
1. This provider does not support PowerShell Direct session.
2.	Using the NanoServerPackage provider 1.0.1.0 to search for packages fails in Windows Containers. As a workaround, you may use the NanoServerPackage provider on another machine to download the packages, then copy and DISM install them in the container.

## Fixed issues in v1.0.1.0
1. In v0.1.1.0, you cannot install Microsoft-NanoServer-IIS-Package and Microsoft-NanoServer-SCVMM-Package online. There are two workarounds:

   i. Install another package that will require reboot such as Microsoft-NanoServer-Storage-Package first and without rebooting, install the required package.
   
   ii. Install these packages offline using -ToVhd

2. In v0.1.1.0, you might see an error as shown below while installing certain packages. This is mainly because this provider does not support discovering and installing dependencies. For these cases, refer to <a href="https://technet.microsoft.com/en-us/library/mt126167(v=ws.12).aspx">guide on Getting Started with Nano Server</a> to identify the dependencies.
```
install-package : Add-WindowsPackage failed. Error code = 0x800f0922
    + CategoryInfo          : InvalidOperation: (System.String[]:String) [Install-Package], Exception
    + FullyQualifiedErrorId : FailedToInstall,Install-PackageHelper,Microsoft.PowerShell.PackageManagement.Cmdlets.InstallPackage
```
