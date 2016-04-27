$vhdPath = "C:\test\something.vhd"
$culture = (Get-Culture).Name
$dcbPackage = "Microsoft-NanoServer-DCB-Package"
$computePackage = "Microsoft-NanoServer-Compute-Package"
$containersPackage = "Microsoft-NanoServer-Containers-Package"
$providerName = "NanoServerPackage"
$requiredVersion = "10.0.14300.1000"

Describe "Install-NanoServerPackage Stand-Alone" {
    It "ERROR: Install with no name" {
        { Install-NanoServerPackage -Name '' } | should throw
    }

    It "ERROR: Install with wrong culture" {
        { Install-NanoServerPackage -Name $dcbPackage -Culture wrong } | should throw
    }

    It "ERROR: Install unknown packages" {
        { Install-NanoServerPackage -Name 'wrong package name' } | should throw
    }

    It "Install DCB package" {
        $package = Install-NanoServerPackage -Name $dcbPackage -Force

        $package.Name | should match $dcbPackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install DCB package to vhd" {
        $package = Install-NanoServerPackage -Name $dcbPackage -ToVhd $vhdPath -Force

        $package.Name | should match $dcbPackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -FromVhd $vhdPath
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "ERROR: Install compute package with wrong culture" {
        { $package = Install-NanoServerPackage -Name $dcbPackage -Culture it-it -Force} | should throw
    }

    It "Install compute package with correct culture" {
        $package = Install-NanoServerPackage -Name $computePackage -Culture $culture -Force

        $package.Name | should match $computePackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install compute package with correct culture to vhd" {
        $package = Install-NanoServerPackage -Name $computePackage -Culture $culture -ToVhd $vhdPath -Force

        $package.Name | should match $computePackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -FromVhd $vhdPath
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install compute package by piping from find" {
        $package = (Find-NanoServerPackage -Name *nanoserver-compute* | Install-NanoServerPackage -Force)

        $package.Name | should match $computePackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install containers package with required version" {
        $package = Install-NanoServerPackage -Name $containersPackage -Culture $culture -RequiredVersion $requiredVersion -Force

        $package.Name | should match $containersPackage
        $package.Culture | should match $culture
        $package.Version.ToString() | should match $requiredVersion

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -RequiredVersion $requiredVersion
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
        $getPackage.Version.ToString() | should match $requiredVersion
    }

    It "Install containers package with required version to vhd" {
        $package = Install-NanoServerPackage -Name $containersPackage -Culture $culture -RequiredVersion $requiredVersion -ToVhd $vhdPath -Force

        $package.Name | should match $containersPackage
        $package.Culture | should match $culture
        $package.Version | should match $requiredVersion

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -RequiredVersion $requiredVersion -FromVhd $vhdPath
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install multiple packages to VHD" {
        $packages = Install-NanoServerPackage -Name $containersPackage,$computePackage -Culture $culture -Force

        $packages.Count | should be 2
        $packages.Name -contains $containersPackage | should be $true
        $packages.Name -contains $computePackage | should be $true
    }

    It "Install multiple packages to VHD" {
        $packages = Install-NanoServerPackage -Name $containersPackage,$computePackage -Culture $culture -Force -ToVhd $vhdPath

        $packages.Count | should be 2
        $packages.Name -contains $containersPackage | should be $true
        $packages.Name -contains $computePackage | should be $true
    }

}

Describe "Install-NanoServerPackage With OneGet" {
    It "ERROR: Install with wildcard name" {
        $Error.Clear()
        Install-Package -Name '*' -ProviderName $providerName -Force -ErrorAction SilentlyContinue
        $Error[0].FullyQualifiedErrorId | should match 'WildCardCharsAreNotSupported,Microsoft.PowerShell.PackageManagement.Cmdlets.InstallPackage'
    }

    It "ERROR: Install with wrong culture" {
        $Error.Clear()
        Install-Package -Name $dcbPackage -Culture wrong -ProviderName $providerName -Force -ErrorAction SilentlyContinue
        $Error[0].FullyQualifiedErrorId | should match 'NoMatchFoundForCriteria,Microsoft.PowerShell.PackageManagement.Cmdlets.InstallPackage'
    }

    It "ERROR: Install unknown packages" {
        $Error.Clear()
        Install-Package -ProviderName $providerName -Name 'wrong package name' -Force -ErrorAction SilentlyContinue
        $Error[0].FullyQualifiedErrorId | should match 'NoMatchFoundForCriteria,Microsoft.PowerShell.PackageManagement.Cmdlets.InstallPackage'
    }

    It "Install DCB package" {
        $package = Install-Package -ProviderName $providerName -Name $dcbPackage -Force

        $package.Name | should match $dcbPackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install DCB package to vhd" {
        $package = Install-Package -ProviderName $providerName -Name $dcbPackage -ToVhd $vhdPath -Force

        $package.Name | should match $dcbPackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -FromVhd $vhdPath
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "ERROR: Install compute package with wrong culture" {
        $Error.Clear()
        $package = Install-Package -ProviderName $providerName -Name $dcbPackage -Culture it-it -Force -ErrorAction SilentlyContinue
        $Error[0].FullyQualifiedErrorId | should match 'NoMatchFoundForCriteria,Microsoft.PowerShell.PackageManagement.Cmdlets.InstallPackage'
    }

    It "Install compute package with correct culture" {
        $package = Install-Package -ProviderName $providerName -Name $computePackage -Culture $culture -Force

        $package.Name | should match $computePackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName-Name $package.Name -Culture $package.Culture
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install compute package with correct culture to vhd" {
        $package = Install-Package -ProviderName $providerName -Name $computePackage -Culture $culture -ToVhd $vhdPath -Force

        $package.Name | should match $computePackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -FromVhd $vhdPath
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install compute package by piping from find" {
        $package = (Find-Package -ProviderName $providerName -Name *compute* | Install-Package -Force)

        $package.Name | should match $computePackage
        $package.Culture | should match $culture

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install containers package with required version" {
        $package = Install-Package -ProviderName $providerName -Name $containersPackage -Culture $culture -RequiredVersion $requiredVersion -Force

        $package.Name | should match $containersPackage
        $package.Culture | should match $culture
        $package.Version.ToString() | should match $requiredVersion

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -RequiredVersion $requiredVersion
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
        $getPackage.Version.ToString() | should match $requiredVersion
    }

    It "Install containers package with required version to vhd" {
        $package = Install-Package $containersPackage -ProviderName $providerName -Culture $culture -RequiredVersion $requiredVersion -ToVhd $vhdPath -Force

        $package.Name | should match $containersPackage
        $package.Culture | should match $culture
        $package.Version | should match $requiredVersion

        $getPackage = Get-Package -ProviderName $providerName -Name $package.Name -Culture $package.Culture -RequiredVersion $requiredVersion -FromVhd $vhdPath
        $getPackage.Name | should match $package.Name
        $getPackage.Culture | should match $package.Culture
    }

    It "Install multiple packages to VHD" {
        $packages = Install-Package -ProviderName $providerName -Name $containersPackage,$computePackage -Culture $culture -Force

        $packages.Count | should be 2
        $packages.Name -contains $containersPackage | should be $true
        $packages.Name -contains $computePackage | should be $true
    }

    It "Install multiple packages to VHD" {
        $packages = Install-Package -ProviderName $providerName -Name $containersPackage,$computePackage -Culture $culture -Force -ToVhd $vhdPath

        $packages.Count | should be 2
        $packages.Name -contains $containersPackage | should be $true
        $packages.Name -contains $computePackage | should be $true
    }
}