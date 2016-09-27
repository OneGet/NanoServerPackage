
# you need to modify 
# 1. $vhdPath to match your Nano Vm

$vhdPath = "C:\test\rtmRefreshStdEdition.vhd"


$providerName = "NanoServerPackage"
$commonPackages = @(
    "Microsoft-NanoServer-Defender-Package",
    "Microsoft-NanoServer-ShieldedVM-Package",
    "Microsoft-NanoServer-Compute-Package",
    "Microsoft-NanoServer-SecureStartup-Package",
    "Microsoft-NanoServer-Storage-Package",
    "Microsoft-NanoServer-OEM-Drivers-Package",
    "Microsoft-NanoServer-DSC-Package",
    "Microsoft-NanoServer-DNS-Package",
    "Microsoft-NanoServer-IIS-Package",
    "Microsoft-NanoServer-DCB-Package",
    "Microsoft-NanoServer-FailoverCluster-Package",
    "Microsoft-NanoServer-Host-Package",
    "Microsoft-NanoServer-Guest-Package",
    "Microsoft-NanoServer-Containers-Package",
    "Microsoft-NanoServer-SCVMM-Package",
    "Microsoft-NanoServer-SCVMM-Compute-Package",
    "Microsoft-NanoServer-SoftwareInventoryLogging-Package"
    )
$packagesForServerDataCenter = @(
    "Microsoft-NanoServer-ShieldedVM-Package")
$allPackages = $commonPackages + $packagesForServerDataCenter
$cultures = ("cs-cz", "de-de", "en-us", "es-es", "fr-fr", "hu-hu", "it-it", "ja-jp", "ko-kr", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ru-ru", "sv-se", "tr-tr", "zh-cn", "zh-tw")


Describe "Find 18 packages" {
    It "Find all 18 packages" {
        foreach ($package in $allPackages) {
            foreach ($culture in $cultures) {
                $desiredPackage = Find-NanoServerPackage -Name $package -Culture $culture -Verbose
                $desiredPackage.Name | should match $package
                $desiredPackage.Culture | should match $culture
            }
        }
    }
}

Describe "Save 18 packages" {
    $savePackagePath = "$env:TMP\NanoServerPackageTest"
    md $savePackagePath

    It "Save all 18 packages" {
        foreach ($package in $allPackages) {
            Write-Host "Saving package $package"

            foreach ($culture in $cultures) {
                $desiredPackage = Save-NanoServerPackage -Name $package -Culture $culture -Path $savePackagePath -Verbose

                $desiredPackage.Name | should match $package
                $desiredPackage.Culture | should match $culture

                (Get-ChildItem $savePackagePath).Count | should be 2

                Remove-Item "$savePackagePath\*.cab"
            }
        }
    }
}

Describe "Install 18 packages" {
    It "Install all common packages" {

        # Install all of them
        foreach ($package in $commonPackages) {
            Write-Host "Installing package $package"
            Install-NanoServerPackage -Name $package

            $installedPackage = Get-Package -ProviderName $providerName -Name $package -Verbose
            $installedPackage.Name -match $package | should be $true
        }
    }

    It "Install server data center packages" {
        foreach ($package in $packagesForServerDataCenter) {
            Write-Host "Installing package $package"
            Install-NanoServerPackage -Name $package

            $installedPackage = Get-Package -ProviderName $providerName -Name $package -Verbose
            $installedPackage.Name -match $package | should be $true
        }
    }

    It "Install all common packages to offline image" {

        # Install all of them
        foreach ($package in $commonPackages) {
            Write-Host "Installing package $package to vhd $vhdPath"
            Install-NanoServerPackage -Name $package -ToVhd $vhdPath -Verbose

            $installedPackage = Get-Package -ProviderName $providerName -Name $package -FromVhd $vhdPath
            $installedPackage.Name -match $package | should be $true
        }
    }

    It "Install server data center packages to offline image" {

        # Install all of them
        foreach ($package in $packagesForServerDataCenter) {
            Write-Host "Installing package $package to vhd $vhdPath"
            Install-NanoServerPackage -Name $package -ToVhd $vhdPath -Verbose

            $installedPackage = Get-Package -ProviderName $providerName -Name $package -FromVhd $vhdPath
            $installedPackage.Name -match $package | should be $true
        }
    }
}