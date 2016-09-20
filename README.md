# NanoServerPackage Provider
A PackageManagement (aka <a href="http://www.oneget.org">OneGet</a>) provider to find and install Optional Windows Packages (Windows feature and role) for NanoServer. For general information about these packages, please refer to the <a href="https://technet.microsoft.com/en-us/library/mt126167(v=ws.12).aspx">guide on Getting Started with Nano Server</a>.

##### Note 
The current public version 0.1.1.0 of NanoServerPackage Provider from the PowerShellGallery.com only supports Nano Server with Technical Preview 5 (TP5) version, i.e. 10.0.14300.1000, that is public in April 2016. It DOES NOT support Nano Server with newer version of TP5. Please make sure you use the correct version of NanoServerPackage provider.

## Installing the provider
You can install the provider from PowerShellGallery using the following PackageManagement commands:
```
Install-PackageProvider NanoServerPackage
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

The provider needs to be loaded in PowerShell before you can use any of the cmdlet in the second set (otherwise, OneGet may not use NanoServerPackage when running those cmdlets). You can load the provider either by running ```Import-PackageProvider NanoServerPackage``` or using any of the generic OneGet cmdlet with ```-ProviderName NanoServerPackage``` (for example: ```Find-Package -ProviderName NanoServerPackage```)

## Searching for Windows Packages

Both ```Find-NanoServerPackage``` and ```Find-Package``` search and return a list of Windows Packages available in the online repository. You may want to provide ```-ProviderName NanoServerPackage``` to ```Find-Package``` so that OneGet will not use other providers. In addition, when using the generic OneGet cmdlet, you can also use a switch ```-DisplayCulture``` so the culture of the packages returned will be displayed.

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
Find-NanoServerPackage -RequiredVersion 10.0.14300.100
```
OR
```
Find-Package -ProviderName NanoServerPackage -RequiredVersion 10.0.14300.100 -DisplayCulture
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

## Installing Windows Packages
You can install a Windows Package using either ```Install-NanoServerPackage``` or ```Install-Package```. If you want to install the package to an offline NanoServer image, you can specify the path to the offline image with ```-ToVhd``` parameter. Otherwise, the cmdlets will install the package to the local machine.

Both cmdlets accept pipeline result from the search cmdlets. Please note that these cmdlets currently do not handle dependencies so you will have to install a package and their dependencies in the correct order. Also, the culture of the package has to match the culture of the machine you are installing it to for the package to work properly. The cmdlets have auto-detection logic that will determine the suitable culture. However, you can also use ```-Culture``` parameter to specify the culture that you want to use for the installation.

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
Install version 10.0.14300.1000 version of the Containers package to the local machine
```
Install-NanoServerPackage -Name Microsoft-NanoServer-Containers-Package -RequiredVersion 10.0.14300.1000
```
OR
```
Install-Package -ProviderName NanoServerPackage -Name Microsoft-NanoServer-Containers-Package -DisplayCulture -RequiredVersion 10.0.14300.1000
```

##### Example 3
Install the latest version of the Compute package to the local machine. This latest version has to be less than 11.0
```
Install-NanoServerPackage -Name Microsoft-NanoServer-Compute-Package -MaximumVersion 11.0
```
OR
```
Install-Package -Name Microsoft-NanoServer-Compute-Package -MaximumVersion 11.0 -DisplayCulture
```

##### Example 4
Install the latest version of the DCB package to an offline NanoServer image.
```
Install-NanoServerPackage -Name Microsoft-NanoServer-DCB-Package -ToVhd C:\OfflineVhd.vhd
```
OR
```
Install-Package -Name Microsoft-NanoServer-DCB-Package -ToVhd C:\OfflineVhd.vhd -ProviderName NanoServerPackage -DisplayCulture
```

##### Example 5
Install the Containers package by piping the result from the search cmdlets. Please do not specify ```-ProviderName``` on the ```Install-Package``` cmdlet if you use it this way.
```
Find-NanoServerPackage *Containers* | Install-NanoServerPackage
```
OR
```
Find-Package -ProviderName NanoServerPackage *Containers* | Install-Package -DisplayCulture
```

## Dowloading Windows Packages
You can download a WindowsPackage without installing it by using ```Save-NanoServerPackage``` or ```Save-Package``` cmdlets. Both cmdlets accept pipeline result from the search cmdlets. These cmdlets will download both the feature package and the culture package. If you do not specify the ```-Culture``` parameter, the culture of the local machine will be used.

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
Download and save version 10.0.14300.100 of the NPDS package with de-de culture to the current directory.
```
Save-NanoServerPackage Microsoft-NanoServer-NPDS-Package -Path .\ -Culture de-de -RequiredVersion 10.0.14300.100
```
OR
```
Save-Package -ProviderName NanoServerPackage Microsoft-NanoServer-NPDS-Package -Path .\ -Culture de-de -RequiredVersion 10.0.14300.100 -DisplayCulture
```

##### Example 3
Download and save the it-it version of the Defenders package to the current directory by piping the results from the search cmdlets. Please do not specify ```-ProviderName``` in the ```Save-Package``` cmdlet if you piped result to it.
```
Find-NanoServerPackage -Name *Defenders* -Culture it-it | Save-NanoServerPackage -Path .\
```
OR
```
Find-Package -ProviderName NanoServerPackage *Defenders* -Culture it-it | Save-Package -Path .\ -DisplayCulture
```

## Inventory what Windows Packages are installed
You can search for installed packages on your local NanoServer machine or an offline NanoServer image using ```Get-Package```.

##### Example 1
Search for all Windows Packages installed on the local machine that has version 10.0.14300.1000.
```
Get-Package -ProviderName NanoServerPackage -RequiredVersion 10.0.14300.100 -DisplayCulture
```

##### Example 2
Search for all Windows Packages installed on an offline NanoServer image.
```
Get-Package -ProviderName NanoServerPackage -FromVhd C:\OfflineVhd.vhd -DisplayCulture
```

## Version
0.1.1.0

## Version History
#### 0.1.1.0
Initial public release for Nano Package Providers

### Dependencies
This module has no dependencies

## Known Issues
1. This provider does not support PowerShell Direct session.

2. Currently, you cannot install Microsoft-NanoServer-IIS-Package and Microsoft-NanoServer-SCVMM-Package online. There are two workarounds:

    i. Install another package that will require reboot such as Microsoft-NanoServer-Storage-Package first and without rebooting, install the required package.
    
    ii. Install these packages offline using -ToVhd

3. You might see an error as shown below while installing certain packages. This is mainly because this provider does not support discovering and installing dependencies. For these cases, refer to <a href="https://technet.microsoft.com/en-us/library/mt126167(v=ws.12).aspx">guide on Getting Started with Nano Server</a> to identify the dependencies.
```
install-package : Add-WindowsPackage failed. Error code = 0x800f0922
    + CategoryInfo          : InvalidOperation: (System.String[]:String) [Install-Package], Exception
    + FullyQualifiedErrorId : FailedToInstall,Install-PackageHelper,Microsoft.PowerShell.PackageManagement.Cmdlets.InstallPackage
```
