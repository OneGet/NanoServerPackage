#$here = Split-Path -Parent $MyInvocation.MyCommand.Path
#$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Save.Tests.ps1", ".psm1")
#. "$here\..\$sut"
$minVersion = "10.0.14300.1000"
$maxVersion = "10.0.14393.1000"
$requiredVersion = "10.0.14393.0"

Describe "Save-WindowsPackage Stand-Alone" {

    BeforeAll {

        $pathToSaveWithWildCards = "$env:LOCALAPPDATA\N*Serv*age\Save\"
        $pathToSave = "$env:LOCALAPPDATA\NanoServerPackage\Save\"
        $badPath = "C:\DoesNotExist"
        $cultures = ("cs-cz", "de-de", "en-us", "es-es", "fr-fr", "hu-hu", "it-it", "ja-jp", "ko-kr", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ru-ru", "sv-se", "tr-tr", "zh-cn", "zh-tw")        
        $names = ("microsoft-NanoServEr-containers-package", "microsoft-NanoServEr-compute-package", "microsoft-NanoServEr-dcb-package")

        Import-packageprovider -force -name NanoServerPackage
        Import-module NanoServerPackage -force

        if(-not (Test-Path $pathToSave))
        {
            mkdir $pathToSave
        }

        # Remove all cab files under the save folder
        Remove-Item $pathToSave\*.cab
    }

    AfterAll {
        if(Test-Path $pathToSave)
        {
            rmdir $pathToSave -Force
        }

        "Finished running the Find-NanoServerPackage Stand-Alone tests"        
    }

    It "Save-NanoServerPackage Name, Path" {
        $name = $names | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-NanoServerPackage -Name $name -Path $pathToSaveWithWildCards)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be "en-us"

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion
        
        $results = @()
        $results += (Save-NanoServerPackage -Name $name -Path $pathToSaveWithWildCards -Culture $culture)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture, Minimum Version" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-NanoServerPackage -Name $name -Path $pathToSaveWithWildCards -Culture $culture -MinimumVersion $minVersion)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture, Maximum Version" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-NanoServerPackage -Name $name -Path $pathToSaveWithWildCards -Culture $culture -MaximumVersion $maxVersion)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture, Required Version" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-NanoServerPackage -Name $name -Path $pathToSaveWithWildCards -Culture $culture -RequiredVersion $requiredVersion)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage With Dependencies" {
        try {
            $name = "Microsoft-NanoServer-SCVMM-Compute-Package"
            $culture = $cultures | Get-Random
            $version = $requiredVersion

            $results = @()
            $results += (Save-NanoServerPackage -Name $name -Path $pathToSaveWithWildCards -Culture $culture -RequiredVersion $requiredVersion -Force)

            $results.count | should be 3
            $results.name -contains $name | should be $true
            $results.name -contains "Microsoft-NanoServer-Compute-Package" | should be $true
            $results.name -contains "Microsoft-NanoServer-SCVMM-Package" | should be $true
            $results[0].culture | should match $culture
            $results[1].culture | should match $culture
            $results[2].culture | should match $culture
        }
        finally {
            Remove-Item $pathToSave\*.cab
        }
    }

}

Describe "Save-NanoServerPackage One-Get" {

    BeforeAll {
    
        $pathToSave = "$env:LOCALAPPDATA\NanoServerPackageProvider\Save\"
        $badPath = "C:\DoesNotExist"
        $cultures = ("cs-cz", "de-de", "en-us", "es-es", "fr-fr", "hu-hu", "it-it", "ja-jp", "ko-kr", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ru-ru", "sv-se", "tr-tr", "zh-cn", "zh-tw")        
        $names = ("microsoft-NanoServEr-containers-package", "microsoft-NanoServEr-compute-package", "microsoft-NanoServEr-dcb-package")
    
        Import-packageprovider -force -name NanoServerPackage
        Import-module NanoServerPackage -force

        if(-not (Test-Path $pathToSave))
        {
            mkdir $pathToSave
        }

        # Remove all cab files under the save folder
        Remove-Item $pathToSave\*.cab
    }

    AfterAll {
        if(Test-Path $pathToSave)
        {
            rmdir $pathToSave -Force
        }

        "Finished running the Find-NanoServerPackage Stand-Alone tests"        
    }

    It "Save-NanoServerPackage Name, Path" {
        $name = $names | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-Package -ProviderName NanoServerPackage -Name $name -Path $pathToSave)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be "en-us"

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion
        
        $results = @()
        $results += (Save-Package -ProviderName NanoServerPackage $name -Path $pathToSave -Culture $culture)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture, Minimum Version" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-Package -ProviderName NanoServerPackage -Name $name -Path $pathToSave -Culture $culture -MinimumVersion $minVersion)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture, Maximum Version" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-Package -ProviderName NanoServerPackage -Name $name -Path $pathToSave -Culture $culture -MaximumVersion $maxVersion)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage Name, Path, Culture, Required Version" {
        $name = $names | Get-Random
        $culture = $cultures | Get-Random
        $version = $requiredVersion

        $results = @()
        $results += (Save-Package -ProviderName NanoServerPackage -Name $name -Path $pathToSave -Culture $culture -RequiredVersion $requiredVersion)

        $results.count | should be 1
        $results[0].name | should be $name
        $results[0].version | should be $version
        $results[0].culture | should be $culture

        $outputs = Get-ChildItem $pathToSave -Name *.cab

        foreach($output in $outputs)
        {
            $output | should match $name
            $output | should match $version
        }

        Remove-Item $pathToSave\*.cab
    }

    It "Save-NanoServerPackage With Dependencies" {
        try {
            $name = "Microsoft-NanoServer-SCVMM-Compute-Package"
            $culture = $cultures | Get-Random
            $version = $requiredVersion

            $results = @()
            $results += (Save-Package -ProviderName NanoServerPackage -Name $name -Path $pathToSave -Culture $culture -RequiredVersion $requiredVersion -Force)

            $results.count | should be 3
            $results.name -contains $name | should be $true
            $results.name -contains "Microsoft-NanoServer-Compute-Package" | should be $true
            $results.name -contains "Microsoft-NanoServer-SCVMM-Package" | should be $true
            $results[0].culture | should match $culture
            $results[1].culture | should match $culture
            $results[2].culture | should match $culture
        }
        finally {
            Remove-Item $pathToSave\*.cab
        }
    }
}