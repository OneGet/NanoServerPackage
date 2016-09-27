# only have 1 version for now :(
$minVersion = "10.0.14300.1000"
$maxVersion = "10.0.14393.1000"
$requiredVersion = "10.0.14393.0"
$totalPackages="17"
$computePackage = "Microsoft-NanoServer-Compute-Package"

Describe "Find-NanoServerPackage Stand-Alone" {

    BeforeAll {
        Import-packageprovider -force -name NanoServerPackage
        Import-module NanoServerPackage -force

        $cultures = ("cs-cz", "de-de", "en-us", "es-es", "fr-fr", "hu-hu", "it-it", "ja-jp", "ko-kr", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ru-ru", "sv-se", "tr-tr", "zh-cn", "zh-tw")        
        $names = ("containers", "nanoserver-compute", "defender", "dcb")
    }

    AfterAll {
        "Finished running the Find-NanoServerPackage Stand-Alone tests"
    }

    It "Find NanoServerPackage No Params" {
        
        $command = "Find-NanoServerPackage"
        $results = Invoke-Expression $command
        #Conformed that we have a total of 17 packages and each has 18 lang
        $results.count | should be $totalPackages
    }

    It "Find NanoServerPackage Name" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $nameWithWildCards -Verbose)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name            
        }
    }

    It "Find NanoServerPackage Bad Name" {
        $results = @()
        $results += (Find-NanoServerPackage -Name containers -ErrorAction SilentlyContinue)
        $results.count | should be 0
    }
    
    It "Find NanoServerPackage Minimum Version" {
        $command = Find-NanoServerPackage -MinimumVersion 10.0.10586.103 -name $computePackage
        $command.Name | should match $computePackage
    } 

    It "Find NanoServerPackage Maximum Version" {
         Find-NanoServerPackage -MaximumVersion 10.0.10586.105 -name $computePackage -ErrorAction SilentlyContinue | should throw         
    }
    
    It "Find NanoServerPackage Name, Minimum Version" {
        
        $results = @()
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results += (Find-NanoServerPackage -Name $nameWithWildCards -MinimumVersion $minVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            #$result.Version | should be less than or equal to $minVersion
        }
    }

    It "Find NanoServerPackage Name, Maximum Version" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $nameWithWildCards -MaximumVersion $maxVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            #$result.Version | should be less than or equal to $minVersion
        }
    }

    It "Find NanoServerPackage Name, Minimum-Maximum Version" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $nameWithWildCards -MinimumVersion $minVersion -MaximumVersion $maxVersion)
        $results.count | should be 1
    }

    It "Find NanoServerPackage All Versions No Name" {
        
        $results = @()
        $results += (Find-NanoServerPackage -AllVersions)
        $results.count | should be $totalPackages
    }

    It "Find NanoServerPackage All Versions with Name" {
        
        $results = @()
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results += (Find-NanoServerPackage -Name $nameWithWildCards -AllVersions)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            #$result.Version | should be less than or equal to $minVersion
        }
    }

    It "Find NanoServerPackage Required Version" {
        $results = @()
        $results += (Find-NanoServerPackage -RequiredVersion $requiredVersion)
        $results.count | should be $totalPackages

        foreach($result in $results)
        {
            $result.Version | should be $requiredVersion
        }
    }

    It "Find NanoServerPackage Name, Required Version" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $nameWithWildCards -RequiredVersion $requiredVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            $result.Version | should be $requiredVersion
        }
    }

    It "Find NanoServerPackage Culture" {
        
        $culture = $cultures | Get-Random
        $command = "Find-NanoServerPackage -Culture $culture"
        $results = Invoke-Expression $command
        $results.count | should be $totalPackages

        foreach($result in $results)
        {
            $result.Culture | should be $culture
        }
    }

    It "Find NanoServerPackage Name, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $namewithWildCards -Culture $culture)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
        }
    }

    It "Find NanoServerPackage Name, Minimum Version, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $namewithWildCards -Culture $culture -MinimumVersion $minVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
            #$result.Version | should be greater than or equal $minVersion
        }
    }

    It "Find NanoServerPackage Name, Maximum Version, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $namewithWildCards -Culture $culture -MaximumVersion $maxVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
            #$result.Version | should be less than or equal $maxVersion
        }
    }

    It "Find NanoServerPackage Name, Minimum Version, Maximum Version, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $results = @()
        $namewithWildCards = "*" + $name + "*"
        $results += (Find-NanoServerPackage -Name $namewithWildCards -Culture $culture -MinimumVersion $minVersion -MaximumVersion $maxVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
            #$result.Version | should be greater than or equal $minVersion
            #$result.Version | should be less than or equal $maxVersion
        }
    }

    It "Find NanoServerPackage Name, AllVersions, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $namewithWildCards -Culture $culture -AllVersions)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
        }
    }

    It "Find NanoServerPackage Name, RequiredVersion, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-NanoServerPackage -Name $namewithWildCards -Culture $culture -RequiredVersion $requiredVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.name | should match $name
            $result.Version | should be $requiredVersion
        }
    }

    It "Find NanoServerPackage with Dependencies" {
        $scvmmCompute = Find-NanoServerPackage *scvmm-compute* -RequiredVersion $requiredVersion
        $scvmmCompute.Dependencies[0] | should match "nanoserverpackage:Microsoft-NanoServer-SCVMM-Package/$requiredVersion"
        $scvmmCompute.Dependencies[1] | should match "nanoserverpackage:Microsoft-NanoServer-Compute-Package/$requiredVersion"
    }

}

Describe "NanoServerPackage OneGet" {

    BeforeAll {
        Import-packageprovider -force -name NanoServerPackage
        Import-module NanoServerPackage -force

        $cultures = ("cs-cz", "de-de", "en-us", "es-es", "fr-fr", "hu-hu", "it-it", "ja-jp", "ko-kr", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ru-ru", "sv-se", "tr-tr", "zh-cn", "zh-tw")        
        $names = ("containers", "nanoserver-compute", "defender",  "dcb")
    }

    AfterAll {
        "Finished running the Find-NanoServerPackage Stand-Alone tests"
    }

    It "Find NanoServerPackage No Params" {
        
        $command = "Find-Package -ProviderName NanoServerPackage"
        $results = Invoke-Expression $command
        $results.count | should be $totalPackages
    }

    It "Find NanoServerPackage Name" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $nameWithWildCards)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name            
        }
    }
    <#
    It "Find NanoServerPackage Bad Name" {
        $command = "Find-Package -ProviderName NanoServerPackage -Name containers"
        {Invoke-Expression $command} | should throw
    }
    #>
    It "Find NanoServerPackage Minimum Version" {
        $command = Find-NanoServerPackage -MinimumVersion 10.0.10586.103 -name $computePackage
        $command.Name | should match $computePackage
    }

    It "Find NanoServerPackage Maximum Version" {
        Find-NanoServerPackage -MaximumVersion 10.0.10586.105 -name $computePackage -ErrorAction SilentlyContinue | should throw
    }
    
    It "Find NanoServerPackage Name, Minimum Version" {
        
        $results = @()
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results += (Find-Package -ProviderName NanoServerPackage -Name $nameWithWildCards -MinimumVersion $minVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            #$result.Version | should be less than or equal to $minVersion
        }
    }

    It "Find NanoServerPackage Name, Maximum Version" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $nameWithWildCards -MaximumVersion $maxVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            #$result.Version | should be less than or equal to $minVersion
        }
    }

    It "Find NanoServerPackage Name, Minimum-Maximum Version" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $nameWithWildCards -MinimumVersion $minVersion -MaximumVersion $maxVersion)
        $results.count | should be 1
    }

    It "Find NanoServerPackage All Versions No Name" {
        
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -AllVersions)
        $results.count | should be $totalPackages
    }

    It "Find NanoServerPackage All Versions with Name" {
        
        $results = @()
        $name = "container"
        $nameWithWildCards = "*" + $name + "*"
        $results += (Find-Package -ProviderName NanoServerPackage -Name $nameWithWildCards -AllVersions)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            #$result.Version | should be less than or equal to $minVersion
        }
    }

    It "Find NanoServerPackage Required Version" {
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -RequiredVersion $requiredVersion)
        $results.count | should be $totalPackages

        foreach($result in $results)
        {
            $result.Version | should be $requiredVersion
        }
    }

    It "Find NanoServerPackage Name, Required Version" {
        
        $name = $names | Get-Random
        $nameWithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $nameWithWildCards -RequiredVersion $requiredVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.name | should match $name
            $result.Version | should be $requiredVersion
        }
    }

    It "Find NanoServerPackage Culture" {
        
        $culture = $cultures | Get-Random
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Culture $culture)
        $results.count | should be $totalPackages

        foreach($result in $results)
        {
            $result.Culture | should be $culture
        }
    }

    It "Find NanoServerPackage Name, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $namewithWildCards -Culture $culture)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
        }
    }

    It "Find NanoServerPackage Name, Minimum Version, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $namewithWildCards -Culture $culture -MinimumVersion $minVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
            #$result.Version | should be greater than or equal $minVersion
        }
    }

    It "Find NanoServerPackage Name, Maximum Version, Culture" {
        
        $culture = $cultures | Get-Random
        $results = @()
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results += (Find-Package -ProviderName NanoServerPackage -Name $namewithWildCards -Culture $culture -MaximumVersion $maxVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
            #$result.Version | should be less than or equal $maxVersion
        }
    }

    It "Find NanoServerPackage Name, Minimum Version, Maximum Version, Culture" {
        
        $culture = $cultures | Get-Random
        $results = @()
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results += (Find-Package -ProviderName NanoServerPackage -Name $namewithWildCards -Culture $culture -MinimumVersion $minVersion -MaximumVersion $maxVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
            #$result.Version | should be greater than or equal $minVersion
            #$result.Version | should be less than or equal $maxVersion
        }
    }

    It "Find NanoServerPackage Name, AllVersions, Culture" {
        
        $culture = $cultures | Get-Random
        $name = "containers"
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $namewithWildCards -Culture $culture -AllVersions)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.Name | should match $name
        }
    }

    It "Find NanoServerPackage Name, RequiredVersion, Culture" {
        
        $culture = $cultures | Get-Random
        $name = $names | Get-Random
        $namewithWildCards = "*" + $name + "*"
        $results = @()
        $results += (Find-Package -ProviderName NanoServerPackage -Name $namewithWildCards -Culture $culture -RequiredVersion $requiredVersion)
        $results.count | should be 1

        foreach($result in $results)
        {
            $result.Culture | should be $culture
            $result.name | should match $name
            $result.Version | should be $requiredVersion
        }
    }

    It "Find NanoServerPackage with Dependencies" {$scvmmComputePackages = (Find-Package *scvmm-compute* -RequiredVersion $requiredVersion -ProviderName NanoServerPackage -IncludeDependencies)
        $scvmmComputePackages.Count | should be 3

        $scvmmComputePackages.Name -contains "microsoft-nanoserver-compute-package" | should be $true
        $scvmmComputePackages.Name -contains "microsoft-nanoserver-scvmm-package" | should be $true
        $scvmmComputePackages.Name -contains "microsoft-nanoserver-scvmm-compute-package" | should be $true
    }
}

