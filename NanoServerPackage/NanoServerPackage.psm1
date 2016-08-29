#region Script variables

Microsoft.PowerShell.Core\Set-StrictMode -Version Latest

$script:providerName ="NanoServerPackage"
$script:WindowsPackageExtension = ".cab"
$script:onlinePackageCache = @{}
$script:imageCultureCache = @{}
$script:imagePathCache = @{}
$script:wildcardOptions = [System.Management.Automation.WildcardOptions]::CultureInvariant -bor `
                          [System.Management.Automation.WildcardOptions]::IgnoreCase

$script:WindowsPackage = "$env:LOCALAPPDATA\NanoServerPackageProvider"
$script:downloadedCabLocation = "$script:WindowsPackage\DownloadedCabs"
$script:file_modules = "$script:WindowsPackage\sources.txt"
$script:windowsPackageSources = $null
$script:defaultPackageName = "NanoServerPackageSource"
$script:defaultPackageLocation = "http://go.microsoft.com/fwlink/?LinkID=723027&clcid=0x409"
$script:isNanoServerInitialized = $false
$script:isNanoServer = $false
$script:systemSKU = -1
$script:systemVersion = $null
$script:availablePackages = @()
$separator = "|#|"

#endregion Script variables

#region Stand-Alone

function Find-NanoServerPackage
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$false,
                        Position=0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [System.Version]
        $MinimumVersion,

        [System.Version]
        $MaximumVersion,
        
        [System.Version]
        $RequiredVersion,

        [switch]
        $AllVersions,
        
#        [string[]]
#        $Repository,

        [string]
        $Culture,

        [switch]
        $Force
    )
    
    $PSBoundParameters["Provider"] = $script:providerName

    $packages = PackageManagement\Find-Package @PSBoundParameters

    foreach($package in $packages) {
        Microsoft.PowerShell.Utility\Add-Member -InputObject $package -MemberType NoteProperty -Name "Description" -Value $package.Summary
        $package.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.NanoServerPackageItemInfo") | Out-Null
        $package
    }
}

function Save-NanoServerPackage
{
    [CmdletBinding(DefaultParameterSetName='NameAndPathParameterSet',
                   SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   ParameterSetName='NameAndPathParameterSet')]
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   ParameterSetName='NameAndLiteralPathParameterSet')]
        [ValidateNotNullOrEmpty()]

        [string[]]
        $Name,
        
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='InputOjectAndPathParameterSet')]
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='InputOjectAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,
        
        [Parameter(Mandatory=$false, 
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndPathParameterSet')]
        [Parameter(Mandatory=$false, 
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndLiteralPathParameterSet')]
        [string]
        $Culture,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndLiteralPathParameterSet')]
        [Version]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndLiteralPathParameterSet')]
        [Version]
        $MaximumVersion,
        
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndLiteralPathParameterSet')]
        [Alias('Version')]
        [Version]
        $RequiredVersion,

<#
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameAndLiteralPathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,
#>

        [Parameter(Mandatory=$true, ParameterSetName='NameAndPathParameterSet')]
        [Parameter(Mandatory=$true, ParameterSetName='InputOjectAndPathParameterSet')]
        [string]
        $Path,

        [Parameter(Mandatory=$true, ParameterSetName='NameAndLiteralPathParameterSet')]
        [Parameter(Mandatory=$true, ParameterSetName='InputOjectAndLiteralPathParameterSet')]
        [string]
        $LiteralPath,

        [Parameter()]
        [switch]
        $Force
    )

    Begin
    {
    }

    Process
    {
        # verify name does not have wild card
        foreach ($packageName in $Name)
        {            
            if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($packageName))
            {
                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.Exception `
                            -ExceptionMessage "Name cannot contain wildcards" `
                            -ExceptionObject $packageName `
                            -ErrorId WildCardCharsAreNotSupported `
                            -ErrorCategory InvalidData

                return
            }
        }

        if($InputObject)
        {
            $Name = $InputObject.Name
            $RequiredVersion = $InputObject.Version
            #$Repository = $InputObject.Repository
            $Culture = $InputObject.Culture

            if (-not [string]::IsNullOrWhiteSpace($Culture) -and $Culture.Contains(','))
            {
                $Culture = ''
            }
        }

        if($Path)
        {
            $destinationPath = Resolve-PathHelper -Path $Path `
                                                    -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1

            if(-not $destinationPath -or -not (Microsoft.PowerShell.Management\Test-path $destinationPath))
            {
                $errorMessage = ("Cannot find the path '{0}' because it does not exist" -f $Path)
                ThrowError  -ExceptionName "System.ArgumentException" `
                            -ExceptionMessage $errorMessage `
                            -ErrorId "PathNotFound" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ExceptionObject $Path `
                            -ErrorCategory InvalidArgument
            }
        }
        else
        {
            $destinationPath = Resolve-PathHelper -Path $LiteralPath `
                                                    -IsLiteralPath `
                                                    -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1

            if(-not $destinationPath -or -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $destinationPath))
            {
                $errorMessage = ("Cannot find the path '{0}' because it does not exist" -f $LiteralPath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                            -ExceptionMessage $errorMessage `
                            -ErrorId "PathNotFound" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ExceptionObject $LiteralPath `
                            -ErrorCategory InvalidArgument
            }
        }

        if($Name)
        {
            # no culture given, use culture of the system
            if ([string]::IsNullOrWhiteSpace($Culture))
            {
                $Culture = (Get-Culture).Name
            }

            $listOfNames = @()
            foreach ($packageName in $Name)
            {
                $listOfNames += $packagename
            }

            $findResults = @()
            $findResults += (Find -Name $listOfNames `
                            -MinimumVersion $MinimumVersion `
                            -MaximumVersion $MaximumVersion `
                            -RequiredVersion $RequiredVersion `
                            -Culture $Culture `
                            -Force:$Force)
#                            -Repository $Repository `

            if ($findResults.Count -eq 0)
            {
                Write-Error "No results found for $listOfNames"
                return
            }
            
            foreach($findResult in $findResults)
            {
                $dependenciesToBeInstalled = [System.Collections.ArrayList]::new()
                
                if (-not (Get-DependenciesToInstall -availablePackages $script:availablePackages -culture $Culture -package $findResult -dependenciesToBeInstalled $dependenciesToBeInstalled)) {
                    return
                }

                foreach ($result in $dependenciesToBeInstalled) {
                    $currLang = $result.Culture

                    $skipBase = $false

                    # check whether base package is in list of available packages, if so, don't save
                    foreach ($availablePackage in $script:availablePackages) {
                        if (Test-PackageWithSearchQuery -fullyQualifiedName $availablePackage -name $result.Name -requiredVersion $result.Version -Culture "Base")
                        {
                            # if it is, no need to download base installer
                            $skipBase = $true
                        }                        
                    }

                    if (-not $skipBase) {
                        # Base Installer
                        $fileName_base = Get-FileName -name $result.Name `
							                            -Culture "" `
							                            -version $result.Version.ToString()

                        $destination_base = Join-Path $destinationPath $fileName_base

                        if($PSCmdlet.ShouldProcess($fileName_base, "Save-NanoServerPackage"))
                        {
                            if(Test-Path $destination_base)
                            {
                                if($Force)
                                {
                                    Remove-Item $destination_base

                                    $token = $result.Locations.base
                                    DownloadFile -downloadURL $token -destination $destination_base
                                }
                                else
                                {
                                    # The file exists, not downloading
                                    Write-Information "$fileName_base already existsat $destinationPath. Skipping save."
                                }
                            }
                            else
                            {
                                $token = $result.Locations.base
                                DownloadFile -downloadURL $token -destination $destination_base
                            }
                        }
                    }

                    # Language Installer
                    $fileName_lang = Get-FileName -name $result.Name `
							                        -Culture $currLang `
							                        -version $result.Version.ToString()

                    $destination_lang = Join-Path $destinationPath $fileName_lang

                    if($PSCmdlet.ShouldProcess($fileName_lang, "Save-NanoServerPackage"))
                    {
                        if(Test-Path $destination_lang)
                        {
                            if($Force)
                            {
                                Remove-Item $destination_lang

                                $token = $result.Locations.$currLang
                                DownloadFile -downloadURL $token -destination $destination_lang
                            }
                            else
                            {
                                # The file exists, not downloading
                                Write-Information "$fileName_lang already exists at $destinationPath. Skipping save."
                            }
                        }
                        else
                        {
                            $token = $result.Locations.$currLang
                            DownloadFile -downloadURL $token -destination $destination_lang
                        }
                    }

                    $result
                }
            }
            
        }
    }

    End
    {
    }
}

function Install-NanoServerPackage
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory=$true,
            Position=0,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName='NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]$Name,

        <#
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   ParameterSetName='InputObject')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject
        #>

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [Version]
        $MinimumVersion,

        [parameter(Mandatory=$false,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName='NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [System.String]$Culture,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [Alias('Version')]
        [System.Version]$RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [System.Version]$MaximumVersion,

        [ValidateNotNullOrEmpty()]
        [System.String]$ToVhd,

        [parameter()]
        [switch]$Force,

        [parameter()]
        [switch]$NoRestart

<#        [Parameter(ParameterSetName='NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository
#>
    )

    Begin
    {
    }

    Process
    {
        # verify name does not have wild card
        foreach ($packageName in $Name)
        {
            if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($packageName))
            {
                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.Exception `
                            -ExceptionMessage "Name cannot contain wildcards" `
                            -ExceptionObject $packageName `
                            -ErrorId WildCardCharsAreNotSupported `
                            -ErrorCategory InvalidData

                return
            }   
        }

        # pipeline case where culture passed in is en-us, de-de, etc.
        if (-not [string]::IsNullOrWhiteSpace($Culture) -and $Culture.Contains(','))
        {
            $Culture = ''
        }

        $packagesToBeInstalled = @()

        # do a find first, if there are any errors, don't install
        $packagesToBeInstalled += (Find -Name $Name -MinimumVersion $MinimumVersion -MaximumVersion $MaximumVersion -RequiredVersion $RequiredVersion `
            -Culture $Culture -ErrorAction Stop) # -Repository $Repository

        if ($packagesToBeInstalled.Count -eq 0)
        {
            return
        }

        $mountDrive = $null

        # the available packages on the system
        $availablePackages = $()

        $installedPackage = $null

        if (-not [string]::IsNullOrWhiteSpace($ToVhd))
        {
            if($PSCmdlet.ShouldProcess($ToVhd, "Mount-WindowsImage"))
            {
                $ToVhd = Resolve-PathHelper $ToVhd -callerPSCmdlet $PSCmdlet
            
                if (-not ([System.IO.File]::Exists($ToVhd)))
                {
                    $exception = New-Object System.ArgumentException "$ToVhd does not exist"
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "InvalidVhdPath", $errorCategory, $ToVhd

                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                # mount image
                $mountDrive = New-MountDrive

                Write-Verbose "Mounting $ToVhd to $mountDrive"

                Write-Progress -Activity "Mounting $ToVhd to $mountDrive" -PercentComplete 0

                $null = Mount-WindowsImage -ImagePath $ToVhd -Index 1 -Path $mountDrive

                $mountedVHDEdition = $null

                foreach ($packageToBeInstalled in $packagesToBeInstalled)
                {
                    # if this package can't be install on standard, should do a check
                    if (-not $packageToBeInstalled.Sku.Contains("144"))
                    {
                        # initialize the regkey
                        if ($mountedVHDEdition -eq $null)
                        {
                            $regKey = $null

                            try
                            {
                                reg load HKLM\NANOSERVERPACKAGEVHDSYS "$mountDrive\Windows\System32\config\SOFTWARE" | Out-Null
                                $regKey = dir 'HKLM:\NANOSERVERPACKAGEVHDSYS\Microsoft\Windows NT'
                                $mountedVHDEdition = $regKey.GetValue("EditionID")
                            }
                            catch
                            {
                                # ERROR
                                $mountedVHDEdition = "ERROR"
                            }
                            finally
                            {
                                try
                                {
                                    if ($regKey -ne $null)
                                    {
                                        $regKey.Handle.Close()
                                        [gc]::Collect()
                                        reg unload HKLM\NANOSERVERPACKAGEVHDSYS | Out-Null
                                    }
                                }
                                catch { }
                            }
                        }

                        if ($mountedVHDEdition -eq "ServerStandardNano")
                        {
                            # unmount the drive
                            if ($null -ne $mountDrive)
                            {
                                Write-Progress -Activity "Unmounting mount drive $mountDrive" -PercentComplete 90
                                Write-Verbose "Unmounting mount drive $mountDrive"
                                Remove-MountDrive $mountDrive -discard $true
                                Write-Progress -Completed -Activity "Completed"
                            }

                            $exception = New-Object System.ArgumentException "$($packageToBeInstalled.Name) cannot be installed on this edition of NanoServer"
                            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidData
                            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "WrongNanoServerEdition", $errorCategory, $packageToBeInstalled.Name

                            $PSCmdlet.ThrowTerminatingError($errorRecord)                    
                        }
                    }
                }
            }
        }
        else
        {
            foreach ($packageToBeInstalled in $packagesToBeInstalled)
            {
                # this package can't be installed on standard
                if (IsNanoServer)
                {
                    # if this is a nano, then systemSKU would be populated after isnanoserver call
                    if (-not $packageToBeInstalled.Sku.Contains($script:systemSKU.ToString()))
                    {
                        $exception = New-Object System.ArgumentException "$($packageToBeInstalled.Name) cannot be installed on this edition of NanoServer"
                        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidData
                        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "WrongNanoServerEdition", $errorCategory, $packageToBeInstalled.Name

                        $PSCmdlet.ThrowTerminatingError($errorRecord)                    
                    }

                    # if this is nanoserver, then we should also have the version populated
                    if (-not (NanoServerVersionMatched -dependencyVersionString $packageToBeInstalled.NanoServerVersion -version $script:systemVersion))
                    {
                        $exception = New-Object System.ArgumentException "$($packageToBeInstalled.Name) which requires nanoserver version $($packageToBeInstalled.NanoServerVersion) cannot be installed on this version of NanoServer ($script:systemVersion)"
                        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidData
                        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "WrongNanoServerVersion", $errorCategory, $packageToBeInstalled.Name

                        $PSCmdlet.ThrowTerminatingError($errorRecord)
                    }
                }
            }
        }

        $discard = $false

        try
        {
            # If no force, then just check whether the packages are already installed before proceeding
            if (-not $Force)
            {
                Write-Verbose "Getting available packages"

                # installing online
                if ([string]::IsNullOrWhiteSpace($ToVhd))
                {
                    $availablePackages = (Get-WindowsPackage -Online).PackageName.ToLower()
                }
                else
                {
                    if($PSCmdlet.ShouldProcess($mountDrive, "Get-WindowsPackage"))
                    {
                        Write-Progress -Activity "Getting available packages on $mountDrive" -PercentComplete 10

                        $availablePackages = (Get-WindowsPackage -Path $mountDrive).PackageName.ToLower()
                    }
                }
            }

            if($PSCmdlet.ShouldProcess($Name, "Install-NanoServerPackage"))
            {
                [bool]$success = $false

                if (-not [string]::IsNullOrWhiteSpace($ToVhd))
                {
                    Write-Progress -Activity "Mounting $ToVhd to $mountDrive" -PercentComplete 20
                }

                #Installing the package
                $installedPackage = Install-PackageHelper -Name $Name `
                                                            -Culture $Culture `
                                                            -RequiredVersion $RequiredVersion `
                                                            -MinimumVersion $MinimumVersion `
                                                            -MaximumVersion $MaximumVersion `
                                                            -imagePath $ToVhd `
                                                            -mountDrive $mountDrive `
                                                            -availablePackages $availablePackages `
                                                            -successfullyInstalled ([ref]$success) `
                                                            -Force:$Force `
                                                            -NoRestart:$NoRestart `
                                                            -PackagesToBeInstalled $packagesToBeInstalled
#-source $source `

                if (-not $success)
                {
                    $exception = New-Object System.ArgumentException "Cannot install package $packageName with culture $Culture and version $RequiredVersion"
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "FailedToInstallPackage", $errorCategory, $packageName

                    Write-Error $errorRecord
                    $discard = $true
                    break
                }

                $installedPackage
            }
        }
        catch
        {
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $_.Exception, "FailedToInstallPackage", $errorCategory, $Name
            Write-Error $errorRecord
            $discard = $true
        }
        finally
        {
            # unmount the drive
            if ($null -ne $mountDrive)
            {
                Write-Progress -Activity "Unmounting mount drive $mountDrive" -PercentComplete 90
                Write-Verbose "Unmounting mount drive $mountDrive"
                Remove-MountDrive $mountDrive -discard $discard
                Write-Progress -Completed -Activity "Completed"
            }
        }
    }

    End
    {
    }
}

#endregion Stand-Alone

#region Helpers

function Find
{
    [CmdletBinding()]
    param
    (
        [string[]]
        $Name,

        [System.Version]
        $MinimumVersion,

        [System.Version]
        $MaximumVersion,
        
        [System.Version]
        $RequiredVersion,

        [switch]
        $AllVersions,

        <#[string[]]
        $Repository,
        #>

        [string]
        $Culture,

        [switch]
        $Force
    )

    if(-not (CheckVersion $MinimumVersion $MaximumVersion $RequiredVersion $AllVersions))
    {            
        return $null
    }

    $allSources = Get-Source #$Repository

    $searchResults = @()

    if ($null -eq $Name -or $Name.Count -eq 0)
    {
        $Name = @('')
    }

    foreach($currSource in $allSources)
    {
        foreach ($singleName in $Name)
        {
            if ([string]::IsNullOrWhiteSpace($singleName) -or $singleName.Trim() -eq '*')
            {
                # if no name is supplied but min or max version is supplied, error out
                if ($null -ne $MinimumVersion -or $null -ne $MaximumVersion)
                {
                    ThrowError -CallerPSCmdlet $PSCmdlet `
                                -ExceptionName System.Exception `
                                -ExceptionMessage "Name is required when either MinimumVersion or MaximumVersion parameter is used" `
                                -ExceptionObject $Name `
                                -ErrorId NameRequiredForMinOrMaxVersion `
                                -ErrorCategory InvalidData
                }
            }

            $result = Find-Azure -Name $singleName `
                                    -MinimumVersion $MinimumVersion `
                                    -MaximumVersion $MaximumVersion `
                                    -RequiredVersion $RequiredVersion `
                                    -AllVersions:$AllVersions `
                                    -Repository $currSource `
                                    -Culture $Culture `
                                    -Force:$Force
            
            if($null -eq $result)
            {
                # Error must have been thrown already
                # Just continue
                continue
            }
            
            if ($result.GetType().IsArray -and $result.Count -eq 0)
            {
                $sourceName = $currSource.Name
                Write-Error "No matching packages could be found for $singleName in $sourceName"
                continue
            }

            $searchResults += $result
        }
    }

    return $searchResults
}

function Find-Azure
{
    param
    (
        [string]
        $Name,

        [System.Version]
        $MinimumVersion,

        [System.Version]
        $MaximumVersion,
        
        [System.Version]
        $RequiredVersion,

        [switch]
        $AllVersions,

        [System.Object]
        $Repository,

        [string]
        $Culture,

        [switch]
        $Force
    )

    $searchFile = Get-SearchIndex -Force:$Force -fwdLink $Repository.SourceLocation
    $searchFileContent = Get-Content $searchFile

    if($null -eq $searchFileContent)
    {
        return $null
    }

    if(IsNanoServer)
    {
        $jsonDll = [Microsoft.PowerShell.CoreCLR.AssemblyExtensions]::LoadFrom($PSScriptRoot + "\Json.coreclr.dll")
        $jsonParser = $jsonDll.GetTypes() | Where-Object name -match jsonparser
        $searchContent = $jsonParser::FromJson($searchFileContent)
        $searchStuff = $searchContent.Get_Item("array0")
        $searchData = @()
        foreach($searchStuffEntry in $searchStuff)
        {
            $obj = New-Object PSObject 
            $obj | Add-Member NoteProperty Name $searchStuffEntry.Name
            $obj | Add-Member NoteProperty Version $searchStuffEntry.Version
            $obj | Add-Member NoteProperty Description $searchStuffEntry.Description
            $obj | Add-Member NoteProperty SKU $searchStuffEntry.Sku
            $obj | Add-Member NoteProperty NanoServerVersion $searchStuffEntry.NanoServerVersion

            $languageObj = New-Object PSObject
            $languageDictionary = $searchStuffEntry.Language
            $languageDictionary.Keys | ForEach-Object {
                $languageObj | Add-Member NoteProperty $_ $languageDictionary.Item($_)
            }

            # process dependencies
            if ($searchStuffEntry.ContainsKey("Dependencies")) {
                $dependencies = @()
                foreach ($dep in $searchStuffEntry.Dependencies) {
                    $depObject = New-Object PSObject
                    $depObject | Add-Member NoteProperty Name $dep.Name
                    $depObject | Add-Member NoteProperty Version $dep.Version
                    $dependencies += $depObject
                }

                $obj | Add-Member NoteProperty Dependencies $dependencies
            }

            $obj | Add-Member NoteProperty Language $languageObj
            $searchData += $obj
        }
    }
    else
    {
        $searchData = $searchFileContent | ConvertFrom-Json
    }

    $searchResults = @()
    $searchDictionary = @{}

    # If name is null or whitespace, interpret as *
    if ([string]::IsNullOrWhiteSpace($Name))
    {
        $Name = "*"
    }

    # Handle the version not given scenario
    if((-not ($MinimumVersion -or $MaximumVersion -or $RequiredVersion -or $AllVersions)))
    {
        $MinimumVersion = [System.Version]'0.0.0.0'
    }

    foreach($entry in $searchData)
    {
        $toggle = $false

        # Check if the search string has * in it
        if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name))
        {
            if($entry.name -like $Name)
            {
                $toggle = $true
            }
            else
            {
                continue
            }
        }
        else
        {
            if($entry.name -eq $Name)
            {
                $toggle = $true
            }
            else
            {
                continue
            }
        }

        $thisVersion = Convert-Version $entry.version

        if($MinimumVersion)
        {
            $convertedMinimumVersion = Convert-Version $MinimumVersion

            if(($thisVersion -ge $convertedMinimumVersion))
            {
                if($searchDictionary.ContainsKey($entry.name))
                {
                    $objEntry = $searchDictionary[$entry.name]
                    $objVersion = Convert-Version $objEntry.Version

                    if($thisVersion -gt $objVersion)
                    {
                        $toggle = $true
                    }
                    else
                    {
                        $toggle = $false
                    }
                }
                else
                {
                    $toggle = $true
                }   
            }
            else
            {
                $toggle = $false
            }
        }

        if($MaximumVersion)
        {
            $convertedMaximumVersion = Convert-Version $MaximumVersion

            if(($thisVersion -le $convertedMaximumVersion))
            {
                if($searchDictionary.ContainsKey($entry.name))
                {
                    $objEntry = $searchDictionary[$entry.name]
                    $objVersion = Convert-Version $objEntry.Version

                    if($thisVersion -gt $objVersion)
                    {
                        $toggle = $true
                    }
                    else
                    {
                        $toggle = $false
                    }
                }
                else
                {
                    $toggle = $true
                }
            }
            else
            {
                $toggle = $false
            }
        }

        if($RequiredVersion)
        {
            $convertedRequiredVersion = Convert-Version $RequiredVersion

            if(($thisVersion -eq $convertedRequiredVersion))
            {
                $toggle = $true                
            }
            else
            {
                $toggle = $false
            }
        }

        if($AllVersions)
        {
            if($toggle)
            {
                $searchResults += $entry
            }
        }

        if($toggle)
        {
            if($searchDictionary.ContainsKey($entry.name))
            {
                $searchDictionary.Remove($entry.Name)
            }
            
            $searchDictionary.Add($entry.name, $entry)
        }
    }

    if(-not $AllVersions)
    {
        $searchDictionary.Keys | ForEach-Object {
                $searchResults += $searchDictionary.Item($_)
            }
    }

    $searchLanguageResults = @()

    foreach($searchEntry in $searchResults)
    {
        $EntryName = $searchEntry.Name
        $EntryVersion = $searchEntry.Version
        $EntryDescription = $searchEntry.Description
        $langDict = $searchEntry.Language
        $props= Get-Member -InputObject $langDict -MemberType NoteProperty
        $theSource = $Repository.Name
        $sku = [string]::Join(";", @($searchEntry.Sku))
        $nanoServerVersion = $searchEntry.NanoServerVersion

        $dependencies = @()
        $dependenciesProperty = Get-Member -InputObject $searchEntry -MemberType NoteProperty -Name Dependencies
        if ($null -ne $dependenciesProperty) {
            $dependencies = $searchEntry.Dependencies
        }

        if (-not [string]::IsNullOrWhiteSpace($Culture))
        {
            if(($props.Name -notcontains $Culture) -or `
                ($Culture -eq "base"))
            {
                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.Exception `
                            -ExceptionMessage "Culture: $Culture is not supported" `
                            -ExceptionObject $EntryName `
                            -ErrorId WildCardCharsAreNotSupported `
                            -ErrorCategory InvalidData
                return
            }

            $languageObj = New-Object PSObject
            $languageObj | Add-Member NoteProperty "base" $langDict."base"
            $languageObj | Add-Member NoteProperty $Culture $langDict.$Culture

            $ResultEntry = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                Name = $EntryName
                Version = $EntryVersion
                Description = $EntryDescription
                Source = $theSource
                Locations = $languageObj
                Culture = $Culture
                Sku = $sku
                Dependencies = $dependencies
                NanoServerVersion = $NanoServerVersion
            })
            $ResultEntry.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.NanoServerPackageItemInfo")
            $searchLanguageResults += $ResultEntry
        }
        else
        {
            $langList = @()
            $langListString = ""

            $props.Name | ForEach-Object {
                $langList += $_
                if($_ -ne "base"){
                    $langListString += $_
                    $langListString += ", "
                }
            }

            $langListString = $langListString.Substring(0, $langListString.Length - 2)

            $ResultEntry = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                Name = $EntryName
                Version = $EntryVersion
                Description = $EntryDescription
                Source = $theSource
                Locations = $langDict
                Culture = $langListString
                Sku = $sku
                Dependencies = $dependencies
                NanoServerVersion = $NanoServerVersion
            })
            $ResultEntry.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.NanoServerPackageItemInfo")
            $searchLanguageResults += $ResultEntry
        }
    }
    
    return $searchLanguageResults
}

###
### SUMMARY: Download the file given the URI to the given location
###
function DownloadFile
{
    [CmdletBinding()]
    param($downloadURL, $destination, [switch]$noProgress)
    
    $startTime = Get-Date

    try
    {
        # Download the file
	    Write-Verbose "Downloading $downloadUrl to $destination"
	    $saveItemPath = $PSScriptRoot + "\SaveHTTPItemUsingBITS.psm1"
	    Import-Module "$saveItemPath"
	    Save-HTTPItemUsingBitsTransfer -Uri $downloadURL `
					    -Destination $destination `
                        -NoProgress:$noProgress
	    Write-Verbose "Finished downloading"

        $endTime = Get-Date
        $difference = New-TimeSpan -Start $startTime -End $endTime
        $downloadTime = "Downloaded in " + $difference.Hours + " hours, " + $difference.Minutes + " minutes, " + $difference.Seconds + " seconds."
        Write-Verbose $downloadTime
    }
    catch
    {
        ThrowError -CallerPSCmdlet $PSCmdlet `
                    -ExceptionName $_.Exception.GetType().FullName `
                    -ExceptionMessage $_.Exception.Message `
                    -ExceptionObject $downloadURL `
                    -ErrorId FailedToDownload `
                    -ErrorCategory InvalidOperation        
    }
}

function Install-PackageHelper
{
    [cmdletbinding()]
    param(
        [string[]]$Name,
        [string]$Culture,
        [string]$source,
        [string]$mountDrive,
        [string]$imagePath,
        [ref]$successfullyInstalled,
        [version]$MinimumVersion,
        [version]$MaximumVersion,
        [version][Alias('Version')]$RequiredVersion,
        [string[]]$availablePackages,
        [switch]$Force,
        [switch]$NoRestart,
        [PSCustomObject[]]$PackagesToBeInstalled
    )

    $installedWindowsPackages = @()

    $successfullyInstalled.Value = $false

    if ([string]::IsNullOrWhiteSpace($Culture))
    {
        # if the culture is null for the online case, we can find out easily

        if ([string]::IsNullOrWhiteSpace($mountDrive))
        {
            $Culture = (Get-Culture).Name
        }
        else
        {
            Write-Verbose "Determining the culture of $mountDrive"

            $fileKey = Get-FileKey -filePath $imagePath

            if (-not $script:imageCultureCache.ContainsKey($fileKey))
            {
                $Culture = Get-ImageCulture -mountDrive $mountDrive

                if ($null -eq $Culture)
                {
                    Write-Verbose "Cannot determine culture of $mountDrive with /Get-Intl. Trying to find culture using a sample package"

                    $packagesOnTheMachine = $availablePackages

                    if ($null -eq $packagesOnTheMachine -or $packagesOnTheMachine.Count -eq 0)
                    {
                        $packagesOnTheMachine = (Get-WindowsPackage -Path $mountDrive).PackageName
                    }

                    foreach ($package in $packagesOnTheMachine)
                    {
                        $Culture = $package.Split('~')[3]

                        # we have found a culture from a package installed!
                        if (-not [string]::IsNullOrWhiteSpace($Culture))
                        {
                            break
                        }
                    }
                }

                # if after all that, culture still null then we have to abort
                if ($null -eq $Culture)
                {
                    Write-Warning "Cannot determine culture of the vhd. Please supply it directly."
                    return
                }

                $script:imageCultureCache[$fileKey] = $Culture
            }
            else
            {
                $Culture = $script:imageCultureCache[$fileKey]
            }
        }

        Write-Verbose "The culture to be installed is $Culture"
    }

    foreach ($packageName in $Name)
    { 
        $randomName = [System.IO.Path]::GetRandomFileName()
        $destinationFolder = Join-Path $script:downloadedCabLocation $randomName

        $baseVersion = $null
        $languageVersion = $null

        foreach ($availablePackage in $availablePackages)
        {
            # check whether base package is already installed
            if (Test-PackageWithSearchQuery -fullyQualifiedName $availablePackage -name $packageName -requiredVersion $RequiredVersion -minimumVersion $MinimumVersion -maximumVersion $MaximumVersion -Culture "Base")
            {
                $baseVersion = Convert-Version ($availablePackage.Split('~')[4])
            }
            # check whether language pack is installed
            elseif (Test-PackageWithSearchQuery -fullyQualifiedName $availablePackage -name $packageName -requiredVersion $RequiredVersion -minimumVersion $MinimumVersion -maximumVersion $MaximumVersion -Culture $Culture)
            {
                $languageVersion = Convert-Version ($availablePackage.Split('~')[4])
            }
        }

        # no force and both are installed, just returned
        if (-not $Force)
        {
            if ($null -ne $baseVersion -and $null -ne $languageVersion)
            {
                Write-Verbose "Skipping installed package $packageName"
                $successfullyInstalled.Value = $true

                # returned the package to be installed

                if ($null -ne $PackagesToBeInstalled)
                {
                    $PackagesToBeInstalled | Where-Object {$_.Name -eq $packageName} | ForEach-Object {$_.Culture = $Culture; $_}
                }

                continue
            }
        }

        # This means source is offline
        if ((-not [string]::IsNullOrWhiteSpace($source)) -and (Test-Path $source))
        {
            Write-Verbose "Installing package from $source"
            $savedCabFilesToInstall = @($source)
        }
        else
        {
            if (-not (Test-Path $destinationFolder))
            {
                $null = mkdir $destinationFolder
            }

            Write-Verbose "Downloading cab files to $destinationFolder"
            try {
                $script:availablePackages = $availablePackages
                $savedPackages = Save-NanoServerPackage -Name $packageName -Culture $Culture -RequiredVersion $RequiredVersion -MinimumVersion $MinimumVersion `
                                                    -MaximumVersion $MaximumVersion -Path $destinationFolder -Force
            }
            finally {
                $script:availablePackages = @()
            }
        }

        $savedCabFilesToInstall = @()
        $savedCabFilesToInstallTuple = @()

        foreach ($savedPackage in $savedPackages)
        {
            $basePackageFile = (Join-Path $destinationFolder (Get-FileName -name $savedPackage.Name -Culture "" -version $savedPackage.Version))

            $basePackagePath = ""

            if (Test-Path $basePackageFile) {
                $savedCabFilesToInstall += $basePackageFile
                $basePackagePath = $basePackageFile
            }

            # proceed with installation, 
            $languagePackageFile = (Join-Path $destinationFolder (Get-FileName -name $savedPackage.Name -Culture $Culture -version $savedPackage.Version))

            $langPackagePath = ""

            if (Test-Path $languagePackageFile) {
                $savedCabFilesToInstall += $languagePackageFile
                $installedWindowsPackages += $savedPackage
                $langPackagePath = $languagePackageFile
            }

            $savedCabFilesToInstallTuple += ([System.Tuple]::Create($basePackagePath, $langPackagePath))
        }

        $restartNeeded = $false

        try
        {
            # Installing offline scenario
            if (-not [string]::IsNullOrWhiteSpace($mountDrive))
            {
                # in this scenario, the function that calls us already mount the drive
                Write-Verbose "Installing to mountdrive $mountDrive"
                $successfullyInstalled.Value = Install-CabOfflineFromPath -mountDrive $mountDrive -packagePaths $savedCabFilesToInstall
            }
            else
            {
                Write-Verbose "Installing cab files $savedCabFilesToInstallTuple"                
                $successfullyInstalled.Value = Install-Online $savedCabFilesToInstallTuple -restartNeeded ([ref]$restartNeeded)

                if ($restartNeeded -and (-not $NoRestart))
                {
                    Write-Warning "Restart is needed to complete installation"
                }
            }
        
        }
        catch
        {
            $successfullyInstalled.Value = $false
            ThrowError -CallerPSCmdlet $PSCmdlet `
                        -ExceptionName $_.Exception.GetType().FullName `
                        -ExceptionMessage $_.Exception.Message `
                        -ExceptionObject $Name `
                        -ErrorId FailedToInstall `
                        -ErrorCategory InvalidOperation            
        }
        finally
        {
            # Remove the online source
            if (([string]::IsNullOrWhiteSpace($source)) -or (-not (Test-Path $source)))
            {
                Remove-Item $destinationFolder -Recurse -Force
            }
        }
    }

    $installedWindowsPackages
}

###
### SUMMARY: Checks if the system is nano server or not
### Look into the win32 operating system class
### Returns True if running on Nano 
### False otherwise
###
function IsNanoServer
{
    if ($script:isNanoServerInitialized)
    {
        return $script:isNanoServer
    }
    else
    {
        $script:isNanoServerInitialized = $true
        $operatingSystem = Get-CimInstance -ClassName win32_operatingsystem
        $script:systemSKU = $operatingSystem.OperatingSystemSKU
        $script:systemVersion = [System.Environment]::OSVersion
        $script:isNanoServer = ($systemSKU -eq 109) -or ($systemSKU -eq 144) -or ($systemSKU -eq 143)
        return $script:isNanoServer
    }
}

###
### SUMMARY: Checks if the given destination is kosher or not
###
function CheckDestination
{
    param($Destination)

    # Check if entire path is folder structure
    $dest_item = Get-Item $Destination `
                            -ErrorAction SilentlyContinue `
                            -WarningAction SilentlyContinue

    if($dest_item -is [System.IO.DirectoryInfo])
    {
        return $true
    }
    else
    {
        Write-Verbose "Creating directory structure: $Destination"
        mkdir $Destination
        return $true
    }

    return $false
}         

function CheckVersion
{
    param
    (
        [System.Version]$MinimumVersion,
        [System.Version]$MaximumVersion,
        [System.Version]$RequiredVersion,
        [switch]$AllVersions
    )

    if($AllVersions -and $RequiredVersion)
    {
        Write-Error "AllVersions and RequiredVersion cannot be used together"
        return $false
    }

    if($AllVersions -or $RequiredVersion)
    {
        if($MinimumVersion -or $MaximumVersion)
        {
            Write-Error "AllVersions and RequiredVersion switch cannot be used with MinimumVersion or MaximumVersion"
            return $false
        }
    }

    if($MinimumVersion -and $MaximumVersion)
    {
        if($MaximumVersion -lt $MinimumVersion)
        {
            Write-Error "Minimum Version cannot be more than Maximum Version"
            return $false
        }
    }

    return $true
}

function Get-FileName
{
    param(
        [string]$Culture,
        [string]$name,
        [string]$version
    )

    $fileName = $name + "_" + $Culture + "_" + $version.replace('.','-') + $script:WindowsPackageExtension
    return $fileName
}

###
### SUMMARY: Get the search index from Azure
###
function Get-SearchIndex
{
    param
    (
        [switch]
        $Force,

        [string]
        $fwdLink
    )
    
    $fullUrl = Resolve-FwdLink $fwdLink
    $fullUrl = $fullUrl.AbsoluteUri
    $destination = $script:WindowsPackage + "\searchNanoPackageIndex.txt"

    if(Test-Path $destination)
    {
        Remove-Item $destination
        DownloadFile -downloadURL $fullUrl `
                -destination $destination `
                -noProgress
    }
    else
    {
        DownloadFile -downloadURL $fullUrl `
                    -destination $destination `
                    -noProgress
    }
    
    return $destination
} 

function Get-ImageCulture
{
    param
    (
        [string]$mountDrive
    )

    $languageSearch = dism /Image:$mountDrive /Get-Intl

    foreach ($languageString in $languageSearch)
    {
        if ($languageString -match "\s*Default\s*system\s*UI\s*language\s*:\s*([a-z][a-z]-[A-Z][A-Z])\s*")
        {
            return $matches[1]
        }
    }

}

###
### SUMMARY: Resolve the fwdlink to get the actual search URL
###
function Resolve-FwdLink
{
    param
    (
        [parameter(Mandatory=$false)]
        [System.String]$Uri
    )
    
    if(-not (IsNanoServer))
    {
        Add-Type -AssemblyName System.Net.Http
    }
    $httpClient = New-Object System.Net.Http.HttpClient
    $response = $httpclient.GetAsync($Uri)
    $link = $response.Result.RequestMessage.RequestUri


    return $link
}

function Resolve-PathHelper
{
    param 
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $path,

        [Parameter()]
        [switch]
        $isLiteralPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $callerPSCmdlet
    )
    
    $resolvedPaths =@()

    foreach($currentPath in $path)
    {
        try
        {
            if($isLiteralPath)
            {
                $currentResolvedPaths = Microsoft.PowerShell.Management\Resolve-Path -LiteralPath $currentPath -ErrorAction Stop
            }
            else
            {
                $currentResolvedPaths = Microsoft.PowerShell.Management\Resolve-Path -Path $currentPath -ErrorAction Stop
            }
        }
        catch
        {
            $errorMessage = ("Cannot find the path '{0}' because it does not exist" -f $currentPath)
            ThrowError  -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $errorMessage `
                        -ErrorId "PathNotFound" `
                        -CallerPSCmdlet $callerPSCmdlet `
                        -ErrorCategory InvalidOperation
        }

        foreach($currentResolvedPath in $currentResolvedPaths)
        {
            $resolvedPaths += $currentResolvedPath.ProviderPath
        }
    }

    $resolvedPaths
}

### Function to get package dependencies that need to be install
### This will return false if there is a dependency loop
function Get-DependenciesToInstall($availablePackages, $culture, [psobject]$package, [System.Collections.ArrayList]$dependenciesToBeInstalled)
{
    # no dependencies to be installed
    if ($null -eq $package.Dependencies -or $package.Dependencies.Count -eq 0) {
        $dependenciesToBeInstalled.Add($package) | Out-NUll
        return $true
    }

    $permanentlyMarked = [System.Collections.ArrayList]::new()
    $temporarilyMarked = [System.Collections.ArrayList]::new()

    if (-not (DepthFirstVisit -package $package `
                            -temporarilyMarked $temporarilyMarked `
                            -permanentlyMarked $permanentlyMarked `
                            -dependenciesToBeInstalled $dependenciesToBeInstalled `
                            -culture $culture `
                            -availablePackages $availablePackages)) {
        return $false
    }

    return $true
}

function DepthFirstVisit(
    [psobject]$package,
    [System.Collections.ArrayList]$permanentlyMarked,
    [System.Collections.ArrayList]$temporarilyMarked,
    [System.Collections.ArrayList]$dependenciesToBeInstalled,
    $culture,
    $availablePackages) {
    
    # get the hash of the package which is name!#!version
    $hash = $package.Name.ToLower() + "!#!" + (Convert-Version $package.Version)

    if ($temporarilyMarked.IndexOf($hash) -ge 0) {
        # dependency loop!
        return $false        
    }

    # no need to visit permanently marked node
    if ($permanentlyMarked.IndexOf($hash) -ge 0) {
        return $true
    }

    $temporarilyMarked.Add($hash) | Out-Null

    foreach ($dependency in $package.Dependencies) {
        $skip = $false

        # check which dependencies are already installed
        foreach ($availablePackage in $availablePackages)
        {
            # check whether language pack is installed (don't need to check base because if language pack is installed then base must be there)
            if (Test-PackageWithSearchQuery -fullyQualifiedName $availablePackage -name $dependency.Name -requiredVersion $dependency.Version -Culture $culture)
            {
                # if it is, skipped this dependency
                $skip = $true
            }
        }

        if ($skip) {
            continue
        }

        $dependencyPackage = Find -Name $dependency.Name -RequiredVersion $dependency.Version -Culture $culture

        if (-not (DepthFirstVisit -package $dependencyPackage -permanentlyMarked $permanentlyMarked `
                -temporarilyMarked $temporarilyMarked -culture $culture `
                -availablePackages $availablePackages -dependenciesToBeInstalled $dependenciesToBeInstalled)) {
            return $false
        }
    }

    # add to list to install later
    $dependenciesToBeInstalled.Add($package) | Out-Null

    # mark the node permanently
    $permanentlyMarked.Add($hash) | Out-Null

    # remove the temporary mark
    $temporarilyMarked.Remove($hash) | Out-Null

    return $true
}

<#
Parse and return a dependency version
The version string is either a simple version or an arithmetic range
e.g.
     1.0         --> 1.0 ≤ x
     (,1.0]      --> x ≤ 1.0
     (,1.0)      --> x lt 1.0
     [1.0]       --> x == 1.0
     (1.0,)      --> 1.0 lt x
     (1.0, 2.0)   --> 1.0 lt x lt 2.0
     [1.0, 2.0]   --> 1.0 ≤ x ≤ 2.0
 
#>
function NanoServerVersionMatched([string]$dependencyVersionString, [version]$version)
{
    if ([string]::IsNullOrWhiteSpace($dependencyVersionString) -or $version -eq $null)
    {
        return $true
    }

    $dependencyVersionString = $dependencyVersionString.Trim()

    $first = $dependencyVersionString[0]
    $last = $dependencyVersionString[-1]
    
    if ($first -ne '(' -and $first -ne '[' -and $last -ne ']' -and $last -ne ')')
    {
        # stand alone so it is min inclusive
        $versionToBeCompared = Convert-Version $dependencyVersionString

        return ($versionToBeCompared -ge $version)        
    }

    # now dep version string must have length > 3
    if ($dependencyVersionString.Length -lt 3)
    {
        return $true
    }

    if ($first -ne '(' -or $first -ne '[')
    {
        # first character must be either ( or [
        return $true
    }

    if ($last -ne ']' -or $last -ne ')')
    {
        # last character must be either ] or )
        return $true
    }

    # inclusive if the first or last is [ or ], otherwise exclusive
    $minInclusive = ($first -eq '[')
    $maxInclusive = ($last -eq ']')

    $dependencyVersionString = $dependencyVersionString.Substring(1, $dependencyVersionString.Length - 2)

    $parts = $dependencyVersionString.Split(',')
    
    if ($parts.Length -gt 2)
    {
        return $true
    }

    $minVersion = Convert-Version $parts[0]

    if ($part.Length -eq 1)
    {
        $maxVersion = $minVersion
    }
    else
    {
        $maxVersion = Convert-Version $parts[1]
    }

    if ($minVersion -eq $null -and $maxVersion -eq $null)
    {
        return $true
    }

    # now we can compare
    if ($minVersion -ne $null)
    {
        if ($minInclusive)
        {
            # min inclusive so version must be >= minversion
            if ($version -lt $minVersion)
            {
                return $false
            }
        }
        else
        {
            # not mininclusive so version must be > minversion
            if ($version -le $minVersion)
            {
                return $false
            }
        }
    }

    if ($maxVersion -ne $null)
    {
        if ($maxInclusive)
        {
            if ($version -gt $maxVersion)
            {
                return $false
            }
        }
        else
        {
            if ($version -lt $minVersion)
            {
                return $false
            }
        }
    }

    return $true
}

#endregion Helpers

#region Source

###
### SUMMARY: Gets the source from where to get the images
### Initializes the variables for find, download and install
### RETURN:
### Returns the type of 
###
function Get-Source
{
    param($sources)

    Set-ModuleSourcesVariable

    $listOfSources = @()

    # if sources is supplied and we cannot find it, error out
    if((-not [string]::IsNullOrWhiteSpace($sources)) -and (-not $script:windowsPackageSources.Contains($sources)))
    {
        ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.Exception `
                            -ExceptionMessage "Unable to find package source '$sources'. Use Get-PackageSource to see all available package sources." `
                            -ExceptionObject $sources `
                            -ErrorId WildCardCharsAreNotSupported `
                            -ErrorCategory InvalidData
    }

    foreach($mySource in $script:WindowsPackageSources.Values)
    {
        if((-not $sources) -or
            (($mySource.Name -eq $sources) -or
               ($mySource.Location -eq $sources)))
       {
            $tempHolder = @{}

            $location = $mySource.SourceLocation
            $tempHolder.Add("SourceLocation", $location)
            
            $packageSourceName = $mySource.Name
            $tempHolder.Add("Name", $packageSourceName)
            
            $listOfSources += $tempHolder
        }
    }

    return $listOfSources
}

function Set-ModuleSourcesVariable
{
    if(Microsoft.PowerShell.Management\Test-Path $script:file_modules)
    {
        $script:windowsPackageSources = DeSerializePSObject -Path $script:file_modules
    }
    
    if((-not (Microsoft.PowerShell.Management\Test-Path $script:file_modules)))
    {
        $script:windowsPackageSources = [ordered]@{}
        $defaultModuleName = "NanoServerPackageSource"

        $defaultModuleSource = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
            Name = $script:defaultPackageName
            SourceLocation = $script:defaultPackageLocation
            Trusted=$false
            Registered= $true
            InstallationPolicy = "Untrusted"
        })

        $script:windowsPackageSources.Add($defaultModuleName, $defaultModuleSource)
        Save-ModuleSource
    }
}

function Get-PackageProviderName
{
    return $script:providerName
}

###
### SUMMARY: Deserializes the PSObject
###
function DeSerializePSObject
{
    [CmdletBinding(PositionalBinding=$false)]    
    Param
    (
        [Parameter(Mandatory=$true)]        
        $Path
    )
    $filecontent = Microsoft.PowerShell.Management\Get-Content -Path $Path
    [System.Management.Automation.PSSerializer]::Deserialize($filecontent)    
}

function Save-ModuleSource
{
    # check if exists
    if(-not (Test-Path $script:WindowsPackage))
    {
        $null = mkdir $script:WindowsPackage
   }

    # seralize module
    Microsoft.PowerShell.Utility\Out-File -FilePath $script:file_modules `
                                            -Force `
                                            -InputObject ([System.Management.Automation.PSSerializer]::Serialize($script:windowsPackageSources))
}

function Resolve-PackageSource
{
    Set-ModuleSourcesVariable

    $SourceName = $request.PackageSources

    if(-not $SourceName)
    {
        $SourceName = "*"
    }

    foreach($moduleSourceName in $SourceName)
    {
        if($request.IsCanceled)
        {
            return
        }
        
        $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $moduleSourceName,$script:wildcardOptions
        $moduleSourceFound = $false
        
        $script:windowsPackageSources.GetEnumerator() | 
            Microsoft.PowerShell.Core\Where-Object {$wildcardPattern.IsMatch($_.Key)} | 
                Microsoft.PowerShell.Core\ForEach-Object {
                    $moduleSource = $script:windowsPackageSources[$_.Key]
                    $packageSource = New-PackageSourceFromModuleSource -ModuleSource $moduleSource
                    Write-Output -InputObject $packageSource
                    $moduleSourceFound = $true
                }

        if(-not $moduleSourceFound)
        {
            $sourceName  = Get-SourceName -Location $moduleSourceName
            if($sourceName)
            {
                $moduleSource = $script:windowsPackageSources[$sourceName]
                $packageSource = New-PackageSourceFromModuleSource -ModuleSource $moduleSource
                Write-Output -InputObject $packageSource
            }
        }
    }
}

function Add-PackageSource
{
    [CmdletBinding()]
    param
    (
        [string]
        $Name,
         
        [string]
        $Location,

        [bool]
        $Trusted
    )

    Set-ModuleSourcesVariable
    
    $options = $request.Options
    $Default = $false

    if($options)
    {
        foreach( $o in $options.Keys )
        {
            Write-Debug ("OPTION dictionary: {0} => {1}" -f ($o, $options[$o]) )
        }

        if($options.ContainsKey('Default'))
        {
            $Default = $options['Default']
        }
    }

    if($Default)
    {
        $Name = $script:defaultPackageName
        $Location = $script:defaultPackageLocation
    }

    # Check if this package source already exists
    foreach($psModuleSource in $script:windowsPackageSources.Values)
    {
        if(($Name -eq $psModuleSource.Name) -or
                ($Location -eq $psModuleSource.SourceLocation))
        {
            throw "Package Source $Name with $Location already exists"
        }
    }

    # Add new module source
    $moduleSource = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
            Name = $Name
            SourceLocation = $Location            
            Trusted=$Trusted
            Registered= $true
            InstallationPolicy = if($Trusted) {'Trusted'} else {'Untrusted'}
        })

    $script:windowsPackageSources.Add($Name, $moduleSource)
    Save-ModuleSource
    Write-Output -InputObject (New-PackageSourceFromModuleSource -ModuleSource $moduleSource)
}

function Remove-PackageSource
{
    param
    (
        [string]
        $Name
    )
    
    Set-ModuleSourcesVariable -Force

    if(-not $script:windowsPackageSources.Contains($Name))
    {
        Write-Error -Message "Package source $Name not found" `
                        -ErrorId "Package source $Name not found" `
                        -Category InvalidOperation `
                        -TargetObject $Name
        continue
    }

    $script:windowsPackageSources.Remove($Name)

    Save-ModuleSource
}

function New-PackageSourceFromModuleSource
{
    param
    (
        [Parameter(Mandatory=$true)]
        $ModuleSource
    )

    $packageSourceDetails = @{}

    # create a new package source
    $src =  New-PackageSource -Name $ModuleSource.Name `
                              -Location $ModuleSource.SourceLocation `
                              -Trusted $ModuleSource.Trusted `
                              -Registered $ModuleSource.Registered `
                              -Details $packageSourceDetails

    # return the package source object.
    Write-Output -InputObject $src
}

function Get-SourceName
{
    [CmdletBinding()]
    [OutputType("string")]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Location
    )

    Set-ModuleSourcesVariable

    foreach($psModuleSource in $script:windowsPackageSources.Values)
    {
        if(($psModuleSource.Name -eq $Location) -or
           ($psModuleSource.SourceLocation -eq $Location))
        {
            return $psModuleSource.Name
        }
    }
}

#endregion Source

#region OneGet

function Find-Package
{ 
    [CmdletBinding()]
    param
    (
        [string]
        $Name,

        [string]
        $requiredVersion,

        [string]
        $minimumVersion,

        [string]
        $maximumVersion
    )

    $options = $request.Options
    $languageChosen = $null
    $wildcardPattern = $null
    $force = $false
    $allVersions = $false

    # path to the offline nano image
    $imagePath = $null
    $source = $null

    # check out what options the users give us
    if($options)
    {
        foreach( $o in $options.Keys )
        {
            Write-Debug ("OPTION dictionary: {0} => {1}" -f ($o, $options[$o]) )
        }

        if($options.ContainsKey('Force'))
        {
            $force = $options['Force']
        }

        if ($options.ContainsKey("ImagePath"))
        {
            $imagePath = $options['ImagePath']
        }

        if ($options.ContainsKey("Culture"))
        {
            $languageChosen = $options['Culture']
        }

        if ($options.ContainsKey('Source'))
        {
            $source = $options['Source']
        }

        if ($options.ContainsKey('AllVersions'))
        {
            $allVersions = $options['AllVersions']
        }
    }

    <# Commented out because we are not handling source yet
    # no source given then search online
    if ($null -eq $source)
    {
    }
    else
    {
        # If name is null or whitespace, interpret as *
        if ([string]::IsNullOrWhiteSpace($Name))
        {
            $Name = "*"
        }

        if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name))
        {
            $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $Name,$script:wildcardOptions
        }

        # For now, accept offline source like directory
        if (Test-Path $source)
        {
            $count = 0
            $cabFiles = 0
            $files = Get-ChildItem $source -File

            # count number of .cab
            foreach ($file in $files)
            {
                if ([System.IO.Path]::GetExtension($file) -eq '.cab')
                {
                    $cabFiles += 1
                }
            }

            if ($cabFiles -le 0)
            {
                return
            }

            $id = Write-Progress -ParentId 1 -Activity "Finding packages in $source"

            if (-not $id)
            {
                $id = 1
            }

            if (-not [string]::IsNullOrWhiteSpace($imagePath))
            {
                if (-not ([System.IO.File]::Exists($ImagePath)))
                {
                    ThrowError -CallerPSCmdlet $PSCmdlet `
                        -ExceptionName System.ArgumentException `
                        -ExceptionMessage "$ImagePath does not exist" `
                        -ExceptionObject $imagePath `
                        -ErrorId "InvalidImagePath" `
                        -ErrorCategory InvalidData

                    return
                }

                $mountDrive = $null

                # have to mount
                $mountDrive = New-MountDrive
        
                Write-Progress -Activity "Mounting $imagePath to $mountDrive" -PercentComplete 0 -Id $id

                Mount-WindowsImage -ImagePath $imagePath -Index 1 -Path $mountDrive

                try
                {
                    foreach ($file in $files)
                    {
                        if ([System.IO.Path]::GetExtension($file) -eq '.cab')
                        {
                            # scale the percent from 1 to 80 to account for the initial and final step of mounting and dismounting
                            $percentComplete = (($count*80/$cabFiles) + 10) -as [int]
                            $count += 1

                            Write-Progress -Activity `
                                "Getting package information for $($package.PackageName) in $mountDrive" `
                                -PercentComplete $percentComplete `
                                -Id $id 

                            $package = Get-WindowsPackage -PackagePath $file.FullName -Path $mountDrive

                            if (Test-PackageWithSearchQuery -fullyQualifiedName $package.PackageName -requiredVersion $RequiredVersion -Name $Name `
                                -minimumVersion $MinimumVersion -maximumVersion $MaximumVersion -Culture $languageChosen -wildCardPattern $wildcardPattern)
                            {
                                Write-Output (New-SoftwareIdentityPackage $package -src $source -InstallLocation $file.FullName)
                            }
                        }
                    }
                }
                finally
                {
                    # time to unmount
                    Write-Progress -Activity "Unmounting image from $mountDrive" -PercentComplete 90 -Id $id    
                    Remove-MountDrive $mountDrive
                    Write-Progress -Completed -Id $id -Activity "Completed"
                }                
            }
            else
            {
                try
                {
                    #online scenario
                    foreach ($file in $files)
                    {
                        # only checks for .cab extension
                        if ([System.IO.Path]::GetExtension($file) -eq '.cab')
                        {                            
                            $percentComplete = ($count*100/$cabFiles) -as [int]
                            $count += 1
                                                        
                            Write-Progress -Activity `
                                "Getting package information for $($package.PackageName)" `
                                -PercentComplete $percentComplete `
                                -Id $id 

                            $package = Get-WindowsPackage -PackagePath $file.FullName -Online

                            if (Test-PackageWithSearchQuery -fullyQualifiedName $package.PackageName -requiredVersion $RequiredVersion -Name $Name `
                                -minimumVersion $MinimumVersion -maximumVersion $MaximumVersion -Culture $languageChosen -wildCardPattern $wildcardPattern)
                            {
                                Write-Output (New-SoftwareIdentityPackage $package -src $source -InstallLocation $file.FullName)
                            }
                        }
                    }
                }
                finally
                {
                    Write-Progress -Completed -Id $id -Activity "Completed"
                }
            }

        }
        else
        {
            ThrowError -CallerPSCmdlet $PSCmdlet `
                        -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage "Source does not point to a valid directory" `
                        -ErrorId "InvalidSource" `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $options
        }
    }
    #>

    # Let find-windowspackage handle the query
    $convertedRequiredVersion = Convert-Version $requiredVersion
    $convertedMinVersion = Convert-Version $minimumVersion
    $convertedMaxVersion = Convert-Version $maximumVersion

    if ([string]::IsNullOrWhiteSpace($Name))
    {
        $Name = @('*')
    }

    $packages = Find -Name $Name `
        -MinimumVersion $convertedMinVersion `
        -MaximumVersion $convertedMaxVersion `
        -RequiredVersion $convertedRequiredVersion `
        -AllVersions:$AllVersions `
        -Culture $languageChosen `
        -Force:$Force
#        -Repository $Repository

    if ($null -eq $packages)
    {
        return
    }

    # check for packages that match the query
    foreach ($package in $packages)
    {
        $swid = New-SoftwareIdentityFromWindowsPackageItemInfo $package
        Write-Output $swid
    }
}

function Install-Package
{
    [CmdletBinding()]
    param
    (
        [string]
        $fastPackageReference
    )

    Write-Verbose $fastPackageReference

    # path to the offline nano image
    $imagePath = $null

    $options = $request.Options

    $NoRestart = $false

    $force = $false

    # check out what options the users give us
    if($options)
    {
        foreach( $o in $options.Keys )
        {
            Write-Debug ("OPTION dictionary: {0} => {1}" -f ($o, $options[$o]) )
        }

        if($options.ContainsKey('Force'))
        {
            $force = $options['Force']
        }

        if ($options.ContainsKey("ToVhd"))
        {
            $imagePath = $options['ToVhd']
        }

        if ($options.ContainsKey("Culture"))
        {
            $languageChosen = $options['Culture']
        }

        if ($options.ContainsKey("NoRestart"))
        {
            $NoRestart = $options['NoRestart']
        }
    }

    # if image path is supplied and it points to non existing file, returns
    if (-not [string]::IsNullOrWhiteSpace($imagePath) -and (-not ([System.IO.File]::Exists($ImagePath))))
    {
       ThrowError -CallerPSCmdlet $PSCmdlet `
            -ExceptionName System.ArgumentException `
            -ExceptionMessage "$ImagePath does not exist" `
            -ExceptionObject $imagePath `
            -ErrorId "InvalidImagePath" `
            -ErrorCategory InvalidData

        return
    }

    [string[]] $splitterArray = @("$separator")
    
    [string[]] $resultArray = $fastPackageReference.Split($splitterArray, [System.StringSplitOptions]::None)

    $name = $resultArray[0]
    $version = $resultArray[1]
    #$source = $resultArray[2]
    $Culture = $resultArray[3]
    $Sku = $resultArray[4]
    $NanoServerVersion = $resultArray[5]

    # if culture is a string, set it to null (this means user did not supply culture)
    if ($Culture.Contains(','))
    {
        $Culture = ''
    }

    $convertedVersion = Convert-Version $version

    [bool]$success = $false

    $mountDrive = $null

    $availablePackages = @()

    if (-not [string]::IsNullOrWhiteSpace($imagePath))
    {
        $mountDrive = New-MountDrive

        Write-Verbose "Mounting $imagePath to $mountDrive"

        $null = Mount-WindowsImage -ImagePath $imagePath -Index 1 -Path $mountDrive
        
        if (-not $force) {
            $fileKey = Get-FileKey -filePath $imagePath
          
            $availablePackages = @(($script:imagePathCache[$fileKey]).Keys)
        }

        # if this package does not apply to standard, we have to check whether the nano is standard or not
        if (-not $Sku.Contains("144") -or (-not [string]::IsNullOrWhiteSpace($NanoServerVersion)))
        {
            $regKey = $null

            $mountedVhdEdition = "ERROR"
            $vhdNanoServerVersion = $null

            try
            {
                reg load HKLM\NANOSERVERPACKAGEVHDSYS "$mountDrive\Windows\System32\config\SOFTWARE" | Out-Null
                $regKey = dir 'HKLM:\NANOSERVERPACKAGEVHDSYS\Microsoft\Windows NT'
                $mountedVHDEdition = $regKey.GetValue("EditionID")
                $majorVersion = $regKey.GetValue("CurrentMajorVersionNumber")
                $minorVersion = $regKey.GetValue("CurrentMinorVersionNumber")
                $buildVersion = $regKey.GetValue("CurrentBuildNumber")
                $vhdNanoServerVersion = [version]::new($majorVersion, $minorVersion, $buildVersion, 0)
            }
            catch
            {
                # ERROR
                $mountedVHDEdition = "ERROR"
                $vhdNanoServerVersion = $null
            }
            finally
            {
                try
                {
                    if ($regKey -ne $null)
                    {
                        $regKey.Handle.Close()
                        [gc]::Collect()
                        reg unload HKLM\NANOSERVERPACKAGEVHDSYS | Out-Null
                    }
                }
                catch { }
            }

            # if this is not applicable to server standard nano
            if (-not $Sku.Contains("144") -and $mountedVHDEdition -eq "ServerStandardNano")
            {
                # cannot be installed
                # unmount
                if ($null -ne $mountDrive)
                {
                    Write-Verbose "Unmounting mountdrive $mountDrive"
                    Remove-MountDrive $mountDrive -discard $true
                }

                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.ArgumentException `
                            -ExceptionMessage "$name cannot be installed on this edition of NanoServer" `
                            -ExceptionObject $fastPackageReference `
                            -ErrorId FailedToInstall `
                            -ErrorCategory InvalidData
            }

            if (-not [string]::IsNullOrWhiteSpace($NanoServerVersion) -and -not (NanoServerVersionMatched -dependencyVersionString $NanoServerVersion -version $vhdNanoServerVersion))
            {
                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.ArgumentException `
                            -ExceptionMessage "$name which requires nanoserver version $NanoServerVersion cannot be installed on this version of NanoServer ($script:systemVersion)" `
                            -ExceptionObject $fastPackageReference `
                            -ErrorId FailedToInstall `
                            -ErrorCategory InvalidData
            }
        }
    }
    else {
        if (IsNanoServer)
        {
            # if this is a nano, then systemSKU would be populated after isnanoserver call
            if (-not $Sku.Contains($script:systemSKU.ToString()))
            {
                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.ArgumentException `
                            -ExceptionMessage "$name cannot be installed on this edition of NanoServer" `
                            -ExceptionObject $fastPackageReference `
                            -ErrorId FailedToInstall `
                            -ErrorCategory InvalidData
            }

            # if this is nanoserver, then we should also have the version populated
            if (-not (NanoServerVersionMatched -dependencyVersionString $NanoServerVersion -version $script:systemVersion))
            {
                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.ArgumentException `
                            -ExceptionMessage "$name which requires nanoserver version $NanoServerVersion cannot be installed on this version of NanoServer ($script:systemVersion)" `
                            -ExceptionObject $fastPackageReference `
                            -ErrorId FailedToInstall `
                            -ErrorCategory InvalidData
            }
        }

        if (-not $force) {
            $availablePackages = @($script:onlinePackageCache.Keys)
        }
    }

    try
    {
        $installedPackages = Install-PackageHelper -Name $name `
                                                    -Culture $Culture `
                                                    -Version $convertedVersion `
                                                    -mountDrive $mountDrive `
                                                    -successfullyInstalled ([ref]$success) `
                                                    -NoRestart:$NoRestart `
                                                    -availablePackages: $availablePackages

        foreach ($installedPackage in $installedPackages)
        {        
            Write-Output (New-SoftwareIdentityFromWindowsPackageItemInfo ($installedPackage))
        }
    }
    finally
    {
        # unmount
        if ($null -ne $mountDrive)
        {
            Write-Verbose "Unmounting mountdrive $mountDrive"
            Remove-MountDrive $mountDrive -discard (-not $success)
        }
    }
}

function Download-Package
{ 
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FastPackageReference,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Location
    )

    [string[]] $splitterArray = @("$separator")
    
    [string[]] $resultArray = $fastPackageReference.Split($splitterArray, [System.StringSplitOptions]::None)

    $name = $resultArray[0]
    $version = $resultArray[1]
    #$source = $resultArray[2]
    $Culture = $resultArray[3]
    $convertedVersion = Convert-Version $version

    # if culture is a string, set it to null (this means user did not supply culture)
    if ($Culture.Contains(','))
    {
        $Culture = ''
    }

    # no culture given, use culture of the system
    if ([string]::IsNullOrWhiteSpace($Culture))
    {
        $Culture = (Get-Culture).Name
    }

    $force = $false
    $options = $request.Options

    if ($options)
    {
        if ($options.ContainsKey('Force'))
        {
            $force = $options['Force']
        }
    }

    $savedWindowsPackageItems = Save-NanoServerPackage -Name $name `
                                                        -Culture $Culture `
                                                        -RequiredVersion $convertedVersion `
                                                        -Path $Location `
                                                        -Force:$force

    foreach ($savedWindowsPackageItem in $savedWindowsPackageItems)
    {
        Write-Output (New-SoftwareIdentityFromWindowsPackageItemInfo $savedWindowsPackageItem)
    }
}

function Get-InstalledPackage
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [Version]
        $RequiredVersion,

        [Parameter()]
        [Version]
        $MinimumVersion,

        [Parameter()]
        [Version]
        $MaximumVersion
    )

    $options = $request.Options
    $wildcardPattern = $null
    $languageChosen = $null

    # If name is null or whitespace, interpret as *
    if ([string]::IsNullOrWhiteSpace($Name))
    {
        $Name = "*"
    }

    if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name))
    {
        $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $Name,$script:wildcardOptions
    }

    $force = $false

    # path to the offline nano image
    $imagePath = $null

    # check out what options the users give us
    if($options)
    {
        foreach( $o in $options.Keys )
        {
            Write-Debug ("OPTION dictionary: {0} => {1}" -f ($o, $options[$o]) )
        }

        if($options.ContainsKey('Force'))
        {
            $force = $options['Force']
        }

        if ($options.ContainsKey("FromVhd"))
        {
            $imagePath = $options['FromVhd']
        }
        elseif ($options.ContainsKey("ToVhd"))
        {
            # in case of install
            $imagePath = $options['ToVhd']
        }

        if ($options.ContainsKey("Culture"))
        {
            $languageChosen = $options['Culture']

            $cannotConvertCulture = $false

            # try to convert the culture
            try
            {
                $convertedCulture = [cultureinfo]$languageChosen

                # apparently, converting culture 'blah' will not work but 'bla' will work ?!?
                if ($null -eq $convertedCulture -or $null -eq $convertedCulture.DisplayName -or $convertedCulture.DisplayName.Trim() -match "Unknown Language")
                {
                    $cannotConvertCulture = $true
                }
            }
            catch
            {
                $cannotConvertCulture = $true
            }

            # if we cannot convert culture, throw error
            if ($cannotConvertCulture)
            {
                ThrowError -CallerPSCmdlet $PSCmdlet `
                            -ExceptionName System.ArgumentException `
                            -ExceptionMessage "$languageChosen is not a valid culture" `
                            -ExceptionObject $languageChosen `
                            -ErrorId InvalidCulture `
                            -ErrorCategory InvalidData
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($imagePath))
    {
        $mountDrive = New-MountDrive   

        Write-Verbose "Mounting $imagePath to $mountDrive"

        $id = Write-Progress -ParentId 1 -Activity "Getting packages information"
        if (-not $id)
        {
            $id = 1
        }

        Write-Progress -Activity "Mounting $imagePath to $mountDrive" -PercentComplete 0 -Id $id

        Mount-WindowsImage -ImagePath $imagePath -Index 1 -Path $mountDrive

        Write-Verbose "Done Mounting"

        # Now we can try to find the packages
        try
        {
            # Get all the available packages on the mountdrive
            $packages = Get-WindowsPackage -Path $mountDrive
            Write-Verbose "Finished getting packages from $mountDrive with $($packages.Count) packages"
            $count = 0

            Write-Progress -Activity "Getting packages information from $mountDrive" -PercentComplete 5 -Id $id
            
            $packagesToBeReturned = New-Object 'System.Collections.Generic.List[string]'

            $availablePackages = $packages.PackageName.ToLower()

            # check for packages that match the query
            foreach ($fullyQualifiedName in $availablePackages)
            {
                if (Test-PackageWithSearchQuery -fullyQualifiedName $fullyQualifiedName -requiredVersion $RequiredVersion -Name $Name `
                    -minimumVersion $MinimumVersion -maximumVersion $MaximumVersion -Culture $languageChosen -wildCardPattern $wildcardPattern)
                {
                    $packagesToBeReturned.Add($fullyQualifiedName)
                }
            }

            $fileKey = Get-FileKey -filePath $imagePath

            $packageDictionary = @{}

            # try to get the cache if it exists, otherwise create one
            if (-not $script:imagePathCache.ContainsKey($fileKey))
            {                    
                $script:imagePathCache.Add($fileKey, $packageDictionary)
            }

            $packageDictionary = $script:imagePathCache[$fileKey]

            foreach ($fullyQualifiedName in $availablePackages)
            {
                if (-not $packageDictionary.ContainsKey($fullyQualifiedName))
                {
                    $packageDictionary[$fullyQualifiedName] = $null
                }
            }

            # Before we get more details, we will clump together base and language pack if they have same name and version
            if ($packagesToBeReturned.Count -gt 0)
            {
                $packagesToBeReturned = Filter-Packages $packagesToBeReturned
            }

            foreach ($package in $packagesToBeReturned)
            {
                # scale the percent from 1 to 80 to account for the initial and final step of mounting and dismounting
                $percentComplete = (($count*80/$packages.Count) + 10) -as [int]
                $count += 1

                Write-Progress -Activity `
                    "Getting package information for $package in $mountDrive" `
                    -PercentComplete $percentComplete `
                    -Id $id                

                # store the information in cache if it's not there or if user uses force
                if ((-not $packageDictionary.ContainsKey($package)) -or ($null -eq $packageDictionary[$package]) -or $force)
                {
                    Write-Debug "Getting information for package $package and storing it in cache"
                    # store the information in cache
                    $packageDictionary[$package.ToLower()] = Get-WindowsPackage -PackageName $package -Path $mountDrive
                }

                Write-Output (New-SoftwareIdentityPackage $packageDictionary[$package.ToLower()] -src $imagePath)
            }

            # Get the list of packages that are in the cache but not in the latest list we have
            $packageToBeRemoved = @()
            foreach ($pkg in $packageDictionary.GetEnumerator())
            {
                if (-not $availablePackages.Contains($pkg.Name))
                {
                    $packageToBeRemoved += $pkg.Name
                }
            }

            # Remove packages in this list from the cache
            foreach ($pkg in $packageToBeRemoved)
            {
                if ($packageDictionary.ContainsKey($pkg))
                {
                    $packageDictionary.Remove($pkg)
                }
            }
        }
        finally
        {
            Write-Progress -Activity "Unmounting image from $mountDrive" -PercentComplete 90 -Id $id
            # Unmount and delete directory
            Remove-MountDrive $mountDrive
            Write-Progress -Completed -Id $id -Activity "Completed"
        }
    }
    else
    {
        $count = 0;
        $id = Write-Progress -ParentId 1 -Activity "Getting packages information"
        if (-not $id)
        {
            $id = 1
        }
        
        Write-Progress -Activity "Getting available packages on the system" -PercentComplete 0 -Id $id
        # getting the packages on the current operating system
        # getting basic information about all the packages online
        $packages = Get-WindowsPackage -Online

        try
        {
            $packagesToBeReturned = New-Object 'System.Collections.Generic.List[string]'
            $availablePackages = $packages.PackageName.ToLower()

            # Get the list of packages that match what the user input
            foreach ($fullyQualifiedName in $availablePackages)
            {
                if (Test-PackageWithSearchQuery -fullyQualifiedName $fullyQualifiedName -requiredVersion $RequiredVersion -Name $Name `
                    -minimumVersion $MinimumVersion -maximumVersion $MaximumVersion -Culture $languageChosen -wildCardPattern $wildCardPattern)
                {
                    # Store the whole name instead of just the name without language or version
                    $packagesToBeReturned.Add($fullyQualifiedName)
                }

                if (-not ($script:onlinePackageCache.ContainsKey($fullyQualifiedName)))
                {
                    $script:onlinePackageCache[$fullyQualifiedName] = $null
                }
            }

            # nothing matched!
            if ($packagesToBeReturned.Count -gt 0)
            {
                # Before we get more details, we will clump together base and language pack if they have same name and version
                $packagesToBeReturned = Filter-Packages $packagesToBeReturned
            }

            # Only update the list of packages that the user gives
            foreach ($package in $packagesToBeReturned)
            {
                $percentComplete = ($count*90/$packages.Count + 10) -as [int]
                Write-Progress -Activity "Getting package information for $($package)" -PercentComplete $percentComplete -Id $id
                $count += 1;

                # store the information in cache if it's not there or if user uses force
                if ((-not $script:onlinePackageCache.ContainsKey($package)) -or ($null -eq $script:onlinePackageCache[$package]) -or $force)
                {
                    Write-Debug "Getting information for package $package and storing it in cache"
                    # store the information in cache
                    $script:onlinePackageCache[$package.ToLower()] = Get-WindowsPackage -Online -PackageName $package
                }

                if ($script:onlinePackageCache.ContainsKey($package))
                {
                    # convert package to swid and return
                    Write-Output (New-SoftwareIdentityPackage $script:onlinePackageCache[$package] -src "Local Machine")
                }
            }
            
            # Get the list of packages that are in the cache but not in the latest list we have
            $packageToBeRemoved = @()
            foreach ($pkg in $script:onlinePackageCache.GetEnumerator())
            {
               if (-not $availablePackages.Contains($pkg.Name))
                {
                    $packageToBeRemoved += $pkg.Name
                }
            }

            # Remove packages in this list from the cache
            foreach ($pkg in $packageToBeRemoved)
            {
                if ($script:onlinePackageCache.ContainsKey($pkg))
                {
                    $script:onlinePackageCache.Remove($pkg)
                }
            }
        }
        finally 
        {
            Write-Progress -Completed -Id $id -Activity "Completed"
        }
    }
}

function Uninstall-Package
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fastPackageReference
    )


    Write-Verbose $fastPackageReference

    # path to the offline nano image
    $imagePath = $null

    $options = $request.Options

    $NoRestart = $false

    $force = $false

    $languageChosen = $null

    # check out what options the users give us
    if($options)
    {
        foreach( $o in $options.Keys )
        {
            Write-Debug ("OPTION dictionary: {0} => {1}" -f ($o, $options[$o]) )
        }

        if($options.ContainsKey('Force'))
        {
            $force = $options['Force']
        }

        if ($options.ContainsKey("FromVhd"))
        {
            $imagePath = $options['FromVhd']
        }

        if ($options.ContainsKey("Culture"))
        {
            $languageChosen = $options['Culture']
        }

        if ($options.ContainsKey("NoRestart"))
        {
            $NoRestart = $options['NoRestart']
        }
    }

    # if image path is supplied and it points to non existing file, returns
    if (-not [string]::IsNullOrWhiteSpace($imagePath) -and (-not ([System.IO.File]::Exists($ImagePath))))
    {
       ThrowError -CallerPSCmdlet $PSCmdlet `
            -ExceptionName System.ArgumentException `
            -ExceptionMessage "$ImagePath does not exist" `
            -ExceptionObject $imagePath `
            -ErrorId "InvalidImagePath" `
            -ErrorCategory InvalidData

        return
    }

    [string[]] $splitterArray = @("$separator")
    
    [string[]] $resultArray = $fastPackageReference.Split($splitterArray, [System.StringSplitOptions]::None)

    $packageId = $resultArray[4]

    $basePackage = $null

    if ($null -eq $languageChosen) {
        Write-Verbose "No language chosen, removing base too"

        $packageFragments = $packageId.Split("~")

        $packageFragments[3] = ""

        $basePackage = [string]::Join("~", $packageFragments)

        Write-Debug "New package id is $packageId and the base package is $basePackage"
    }

    if (-not [string]::IsNullOrWhiteSpace($imagePath)) {
        # removing from vhd
        $mountDrive = New-MountDrive

        Write-Verbose "Mounting $imagePath to $mountDrive"

        $null = Mount-WindowsImage -ImagePath $imagePath -Index 1 -Path $mountDrive
        
        $success = $false

        try {
            Write-Verbose "Removing $packageId from $mountDrive"

            # time to update the cache since we remove this package
            $fileKey = Get-FileKey -filePath $imagePath

            if ($script:imagePathCache.ContainsKey($fileKey)) {
                $packageDictionary = $script:imagePathCache[$fileKey]

                if ($null -ne $packageDictionary) {
                    if ($packageDictionary.ContainsKey($packageId)) {
                        Remove-WindowsPackage -PackageName $packageId -Path $mountDrive | Out-Null
                        $packageDictionary.Remove($packageId)
                    }
                }
                else {
                    # nothing in cache
                    Remove-WindowsPackage -PackageName $packageId -Path $mountDrive | Out-Null
                }
            }            


            if (-not ([string]::IsNullOrWhiteSpace($basePackage)))
            {
                Remove-WindowsPackage -PackageName $basePackage -Path $mountDrive | Out-Null
            }

            if ($script:imagePathCache.ContainsKey($fileKey)) {
                $packageDictionary = $script:imagePathCache[$fileKey]

                if ($null -ne $packageDictionary)
                {
                    if ($packageDictionary.ContainsKey($packageId))
                    {
                        $packageDictionary.Remove($packageId)
                    }

                    if ((-not [string]::IsNullOrWhiteSpace($basePackage)) -and $packageDictionary.ContainsKey($basePackage))
                    {
                        $packageDictionary.Remove($basePackage)
                    }
                }
            }

            $success = $true
        }
        catch {
            $success = $false
        }
        finally {
            # unmount
            if ($null -ne $mountDrive)
            {
                Write-Verbose "Unmounting mountdrive $mountDrive"
                Remove-MountDrive $mountDrive -discard (-not $success)
            }
        }
    }
    else {
        Write-Verbose "Uninstalling $packageId online"

        $messages = $null

        if ($script:onlinePackageCache.ContainsKey($packageId)) {
            # removing online
            $messages = Remove-WindowsPackage -PackageName $packageId -Online -NoRestart -WarningAction Ignore
            $script:onlinePackageCache.Remove($packageId)
        }

        $restart = $messages -ne $null -and $messages.RestartNeeded

        if (-not [string]::IsNullOrWhiteSpace($basePackage))
        {
            if ($script:onlinePackageCache.ContainsKey($basePackage)) {
                $messages = Remove-WindowsPackage -PackageName $basePackage -Online -NoRestart -WarningAction Ignore       
                $script:onlinePackageCache.Remove($basePackage)
                $restart = $restart -or ($messages -ne $null -and $messages.RestartNeeded)
            }
        }

        if ($restart -and (-not $NoRestart))
        {
            Write-Warning "Restart is needed to complete installation"
        }
    }
}

#endregion OneGet

#region OneGet Helpers

# This is to display long name
function Get-Feature 
{
    Write-Output -InputObject (New-Feature -Name "DisplayLongName")
}

function Get-DynamicOptions
{
    param
    (
        [Microsoft.PackageManagement.MetaProvider.PowerShell.OptionCategory] 
        $category
    )

    switch($category)
    {
        # This is for dynamic options used by install/uninstall and get-packages
        Install 
        {
            # Switch to display culture
            Write-Output -InputObject (New-DynamicOption -Category $Category -Name "NoRestart" -ExpectedType Switch -IsRequired $false)
            # Provides path to image
            Write-Output -InputObject (New-DynamicOption -Category $category -Name "ToVhd" -ExpectedType File -IsRequired $false)
            Write-Output -InputObject (New-DynamicOption -Category $category -Name "FromVhd" -ExpectedType File -IsRequired $false)
            Write-Output -InputObject (New-DynamicOption -Category $Category -Name "DisplayCulture" -ExpectedType Switch -IsRequired $false)
            Write-Output -InputObject (New-DynamicOption -Category $category -Name "Culture" -ExpectedType String -IsRequired $false)
        }
        Package
        {
            # Switch to display culture
            Write-Output -InputObject (New-DynamicOption -Category $Category -Name "DisplayCulture" -ExpectedType Switch -IsRequired $false)
            # Provides path to image
            Write-Output -InputObject (New-DynamicOption -Category $category -Name "ImagePath" -ExpectedType String -IsRequired $false)
            Write-Output -InputObject (New-DynamicOption -Category $category -Name "Culture" -ExpectedType String -IsRequired $false)
        }
        Source
        {
            Write-Output -InputObject (New-DynamicOption -Category $Category -Name "Default" -ExpectedType Switch -IsRequired $false)
        }
    }
}

function Initialize-Provider
{
    write-debug "In $script:providerName - Initialize-Provider"
}

function Get-PackageProviderName
{
    return $script:providerName
}

function New-SoftwareIdentityFromWindowsPackageItemInfo
{
    [Cmdletbinding()]
    param(
        [PSCustomObject]
        $package
    )

    $details = @{}
    $Culture = $package.Culture

    $fastPackageReference = $package.Name + 
                                $separator + $package.version + 
                                $separator + $package.Source + 
                                $separator + $Culture +
                                $separator + $package.Sku +
                                $separator + $package.NanoServerVersion

    $Name = [System.IO.Path]::GetFileNameWithoutExtension($package.Name)

    $deps = (new-Object -TypeName  System.Collections.ArrayList)

    foreach( $dep in $package.Dependencies ) 
    {
        # Add each dependency and say it's from this provider.
        $newDep = New-Dependency -ProviderName $script:providerName `
                                 -PackageName $dep.Name `
                                 -Version $dep.Version
        $deps.Add( $newDep )
    }

    $details["Sku"] = $package.Sku
    $details["NanoServerVersion"] = $package.NanoServerVersion

    $params = @{FastPackageReference = $fastPackageReference;
                Name = $Name;
                Version = $package.version.ToString();
                versionScheme  = "MultiPartNumeric";
                Source = $package.Source;
                Summary = $package.Description;
                Details = $details;
                Culture = $Culture;
                Dependencies = $deps;
                }

    try
    {
        New-SoftwareIdentity @params
    }
    catch
    {
        # throw error because older version of packagemanagement does not have culture key
        $params.Remove("Culture")
        New-SoftwareIdentity @params
    }
}

# this function is used by get-installedpackage
function New-SoftwareIdentityPackage
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Dism.Commands.AdvancedPackageObject]
        $package,

        $src="",

        $InstallLocation=""
    )

    $details = @{}

    $details.Add("Applicable", $package.Applicable)

    if ($null -ne $package.InstallTime)
    {
        $details.Add("InstallTime", $package.InstallTime)
    }

    if ($null -ne $package.CompletelyOfflineCapable)
    {
        $details.Add("CompletelyOfflineCapable", $package.CompletelyOfflineCapable)
    }

    if ($null -ne $package.PackageState)
    {
        $details.Add("PackageState", $package.PackageState)
    }        

    if ($null -ne $package.RestartRequired)
    {
        $details.Add("RestartRequired", $package.RestartRequired)
    }

    if (-not [string]::IsNullOrWhiteSpace($package.ReleaseType))
    {
        $details.Add("ReleaseType", $package.ReleaseType)
    }        

    if ([string]::IsNullOrWhiteSpace($Package.ProductVersion)) {
        $version = "0.0"
    }
    else {
        $version = $Package.ProductVersion
    }

    # format is name~publickeytoken~architecture~language~version

    $packageNameFractions = $Package.PackageName.Split('~')

    if (-not [string]::IsNullOrWhiteSpace($packageNameFractions[0]))
    {
        $name = $packageNameFractions[0]
    }
    else
    {
        $name = $package.PackageName
    }

    # DISM team has a workaround where they add Feature in the name. We should remove that.
    # THIS IS A TEMPORARY FIX
    if ($name -like "*Feature-Package*")
    {
        $name = $name -replace "Feature-Package","Package"
    }

    if (-not [string]::IsNullOrWhiteSpace($packageNameFractions[1]))
    {
        $details.Add("publickey", $packageNameFractions[1])
    }

    if (-not [string]::IsNullOrWhiteSpace($packageNameFractions[2]))
    {
        $details.Add("architecture", $packageNameFractions[2])
    }

    $Culture = $packageNameFractions[3]
    
    # $details.Add("language", $language)

    if (-not [string]::IsNullOrWhiteSpace($packageNameFractions[4]))
    {
        $version = $packageNameFractions[4]
    }

    $fastPackageReference = $name + $separator + $version + $separator + $InstallLocation + $separator + $Culture + $separator + $package.PackageName

    $params = @{FastPackageReference = $fastPackageReference;
                Name = $name;
                Version = $version;
                versionScheme  = "MultiPartNumeric";
                Source = $src;
                Details = $details;
                Culture = $Culture;
                TagId = $Package.PackageName;
                }

    try
    {
        New-SoftwareIdentity @params
    }
    catch
    {
        # throw error because older version of packagemanagement does not have culture key
        $params.Remove("Culture")
        $params.Remove("TagId")
        New-SoftwareIdentity @params
    }
}

function Install-CabOfflineFromPath
{
    [CmdletBinding()]
    param
    (
        [string]$mountDrive,

        [string[]]$packagePaths
    )

    $discard = $false

    $id = Write-Progress -ParentId 1 -Activity "Installing packages"

    if (-not $id)
    {
        $id = 1
    }  

    # Now we can try to install the package
    try
    {
        $count = 0

        foreach ($packagePath in $packagePaths)
        {
            $percentComplete = ($count*100/$packagePaths.Count) -as [int]

            $count += 1

            Write-Progress -Activity `
                "Installing package $packagePath" `
                -PercentComplete $percentComplete `
                -Id $id                

            Write-Verbose "Adding $packagePath to $mountDrive"
            Add-WindowsPackage -PackagePath $packagePath -Path $mountDrive -NoRestart -WarningAction Ignore | Out-Null
        }
    }
    catch
    {
        $discard = $true
        ThrowError -CallerPSCmdlet $PSCmdlet `
                    -ExceptionName $_.Exception.GetType().FullName `
                    -ExceptionMessage $_.Exception.Message `
                    -ExceptionObject $RequiredVersion `
                    -ErrorId FailedToInstall `
                    -ErrorCategory InvalidOperation
    }
    finally
    {
        Write-Progress -Completed -Id $id -Activity "Completed"
    }

    # returns back whether we have successfully installed or not
    return (-not $discard)
}

function Install-Online
{
    [CmdletBinding()]
    param
    (
        $packagePaths,
        [ref]$restartNeeded
    )

    $rollBack = $false

    $count = 0;
    Write-Verbose "Installing $($packagePaths.Count) packages online"
    $id = Write-Progress -ParentId 1 -Activity "Installing packages online"
    if (-not $id)
    {
        $id = 1
    }

    try
    {
        # first package of each pair is base, second is language

        foreach ($packageTuple in $packagePaths)
        {
            $packagePath = $packageTuple.Item1

            $messages = $null

            $restart = $false

            $percentComplete = $count*100/$packagePaths.Count -as [int]

            # valid base path
            if (-not [string]::IsNullOrWhiteSpace($packagePath))
            {
                Write-Progress -Activity "Installing package $($packagePath)" -PercentComplete $percentComplete -Id $id

                Write-Verbose "Installing package $($packagePath)"

                try
                {
                    $messages = Add-WindowsPackage -PackagePath $packagePath -Online -NoRestart -WarningAction Ignore -ErrorAction SilentlyContinue

                    if ($messages -ne $null -and $messages.RestartNeeded)
                    {
                        $restart = $true
                    }
                }
                catch { }
            }

            # now install the language, even if the base fails, sometimes language will succeed
            $packagePath = $packageTuple.Item2

            if (-not [string]::IsNullOrWhiteSpace($packagePath))
            {
                Write-Progress -Activity "Installing package $($packagePath)" -PercentComplete $percentComplete -Id $id

                Write-Verbose "Installing package $($packagePath)"

                # don't try catch here because if this fails, that is it
                $messages = Add-WindowsPackage -PackagePath $packagePath -Online -NoRestart -WarningAction Ignore

                # restart or not
                if (-not $restart -and $messages -ne $null -and $messages.RestartNeeded)
                {
                    $restart = $true
                }

                if ($restart)
                {
                    $restartNeeded.Value = $true
                }

            }

            $count += 1
        }
    }
    catch
    {
        $rollBack = $true
        ThrowError -CallerPSCmdlet $PSCmdlet `
                    -ExceptionName $_.Exception.GetType().FullName `
                    -ExceptionMessage $_.Exception.Message `
                    -ExceptionObject $RequiredVersion `
                    -ErrorId FailedToInstall `
                    -ErrorCategory InvalidOperation
    }
    finally
    {
        Write-Progress -Completed -Id $id -Activity "Completed"
    }

    # returns whether we installed
    return (-not $rollBack)
}

function New-MountDrive
{
    # getting packages from an offline image
    # Mount to directory
    while ($true)
    {
        $randomName = [System.IO.Path]::GetRandomFileName()
        $mountDrive = "$env:LOCALAPPDATA\NanoServerPackageProvider\MountDirectories\$randomName"
            
        if (Test-Path $mountDrive) 
        {
            # We should create a directory that hasn't existed before
            continue;
        }
        else 
        {
            $null = mkdir $mountDrive
            return $mountDrive
        }
    }
}

function Remove-MountDrive([string]$mountDrive, [bool]$discard)
{    
    Write-Verbose "Dismounting $mountDrive"

    # Discard won't save anything we did to the image
    if ($discard)
    {
        $null = Dismount-WindowsImage -Path $mountDrive -Discard
    }
    else
    {
    # save will saves packages that we add to the image
        $null = Dismount-WindowsImage -Path $mountDrive -Save
    }

    Write-Verbose "Deleting $mountDrive"
    Remove-Item -Path $mountDrive -Recurse -Force
}

# Given a fully qualified name of a package with the format name~publickeytoken~architecture~language~version
# checks whether this matches the search query
function Test-PackageWithSearchQuery
{
    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName="FullyQualifiedName")]
        [string]$fullyQualifiedName,

        [Parameter(ParameterSetName="WindowsPackage")]
        [PSCustomObject]$WindowsPackage,

        [string]$requiredVersion,

        [string]$minimumVersion,

        [string]$maximumVersion,

        [string]$name,

        [string]$Culture,

        [System.Management.Automation.WildcardPattern]$wildCardPattern
    )

    if ($null -eq $WindowsPackage)
    {
        # Split up the whole name since the name has language version and packagename in it
        # format is name~publickeytoken~architecture~language~version
        # now we want the package name to have en-us at the end if package is not base
        $packageNameFractions = $fullyQualifiedName.Split('~')
        $packageName = $packageNameFractions[0]
        $packageLanguage = $packageNameFractions[3]
        $version = $packageNameFractions[4]

        # DISM team has a workaround where they add Feature in the name. We should remove that.
        # THIS IS A TEMPORARY FIX
        if ($packageName -like "*Feature-Package")
        {
            $packageName = $packageName -replace "Feature-Package", "Package"
        }
    }
    else
    {
        $packageName = $WindowsPackage.Name
        $packageLanguage = $WindowsPackage.Culture
        $version = $WindowsPackage.version.ToString()
    }

    # there is a chance user supplies *<PackageLanguage>
    if (-not [string]::IsNullOrWhiteSpace($packageLanguage))
    {
        $packageNameWithLanguage = "$packageName" + "_" + "$packageLanguage"
    }   

    if ($null -ne $wildCardPattern)
    {
        # matching already ignore case
        if (-not $wildCardPattern.IsMatch($packageName))
        {
            # we proceed if wildcard match <PackageName>_<PackageLanguage>
            if (-not [string]::IsNullOrWhiteSpace($packageLanguage))
            {
                if (-not $wildCardPattern.IsMatch($packageLanguage))
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
        }
    }
    else
    {
        # no wildcard so check for name if we are given a name
        # eq operation is case insensitive
        if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne $packageName)
        {
            # there is a chance user supplies <PackageName>_<PackageLanguage>
            if (-not [string]::IsNullOrWhiteSpace($packageLanguage))
            {
                # we proceed if name match <PackageName>_<PackageLanguage>
                if ($name -ne $packageNameWithLanguage)
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
        }
    }

    # now we check language if the user providers it
    if (-not [string]::IsNullOrWhiteSpace($Culture))
    {
        # if base, then packageLanguage needs to be null
        if ($Culture -eq 'Base')
        {
            $Culture = ''
        }

        if ($packageLanguage -ne $Culture)
        {
            return $false
        }
    }

    # normalize versions
    $convertedVersion = Convert-Version $version

    # fails to normalize
    if ($null -eq $convertedVersion)
    {
        return $false
    }

    # now we check whether version is matched
    if (-not [string]::IsNullOrWhiteSpace($RequiredVersion))
    {
        $convertedRequiredVersion = Convert-Version $RequiredVersion

        # fails if conversion fails or version does not match
        if (($null -eq $convertedRequiredVersion) -or ($convertedRequiredVersion -ne $convertedVersion))
        {
            return $false
        }
    }

    # packagemanagement will make sure requiredversion is not used with either min or max so we don't have to worry about that
    if (-not [string]::IsNullOrWhiteSpace($MinimumVersion))
    {
        $convertedMinimumVersion = Convert-Version $MinimumVersion

        # the converted version should be greater or equal to min version, not the other way round
        if (($null -eq $convertedMinimumVersion) -or ($convertedMinimumVersion -gt $convertedVersion))
        {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($MaximumVersion))
    {
        $convertedMaximumVersion = Convert-Version $MaximumVersion

        # converted version should be the same or less than max version
        if (($null -eq $convertedMaximumVersion) -or ($convertedMaximumVersion -lt $convertedVersion))
        {
            return $false
        }
    }

    # reached here means the package satisfied the search query
    return $true
}

# Given the path of a file, returns a simple key
# This function assumes that the user test that filePath exists
function Get-FileKey([string]$filePath)
{
    $info = Get-ChildItem $filePath
    return ($filePath + $separator + $info.Length + $separator + $info.CreationTime.ToShortDateString())
}

function Convert-Version([string]$version)
{
    if ([string]::IsNullOrWhiteSpace($version))
    {
        return $null;
    }

    # not supporting semver here. let's try to normalize the versions
    if ($version.StartsWith("."))
    {
        # add leading zeros
        $version = "0" + $version
    }
        
    # let's see how many parts are we given with the version
    $parts = $version.Split(".").Count

    # add .0 dependending number of parts since we need 4 parts
    while ($parts -lt 4)
    {
        $version = $version + ".0"
        $parts += 1
    }

    [version]$convertedVersion = $null

    # try to convert
    if ([version]::TryParse($version, [ref]$convertedVersion))
    {
        return $convertedVersion
    }

    return $null;
}

function Filter-Packages ([string[]]$packagesToBeReturned)
{
    $helperDictionary = @{}
    foreach ($package in $packagesToBeReturned)
    {
        # Split up the whole name since the name has language version and packagename in it
        # format is name~publickeytoken~architecture~language~version
        # now we want the package name to have en-us at the end if package is not base
        $packageNameFractions = $package.Split('~')
        $packageName = $packageNameFractions[0]
        $packageLanguage = $packageNameFractions[3]
        $version = $packageNameFractions[4]
        
        # use name and version as key
        $key = $packageName + "~" + $version

        # haven't encountered this before
        if (-not $helperDictionary.ContainsKey($key))
        {
            $helperDictionary[$key] = @()
        }

        $helperDictionary[$key] += $package
    }

    $result = @()

    foreach ($packageArray in $helperDictionary.Values)
    {
        if ($null -eq $packageArray)
        {
            continue
        }

        # only 1 member, then return that
        if ($packageArray.Count -eq 1)
        {
            $result += $packageArray[0]
            continue
        }

        # otherwise, only returns the 1 with language
        foreach ($possiblePackage in $packageArray)
        {
            $packageNameFractions = $possiblePackage.Split('~')
            $packageName = $packageNameFractions[0]
            $packageLanguage = $packageNameFractions[3]
            $version = $packageNameFractions[4]

            if ([string]::IsNullOrWhiteSpace($packageLanguage))
            {
                continue
            }

            $result += $possiblePackage
        }
    }

    # group according to name
    $groupedName = $result | Group-Object -Property {$_.Split('~')[0]}
    foreach ($groupResult in $groupedName)
    {
        $groupResult.Group | Sort-Object -Property {Convert-Version $_.Split('~')[4]} -Descending
    }
}

# Utility to throw an errorrecord
function ThrowError
{
    param
    (        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]        
        $ExceptionName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,
        
        [System.Object]
        $ExceptionObject,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )
        
    $exception = New-Object $ExceptionName $ExceptionMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $ErrorCategory, $ExceptionObject    
    $CallerPSCmdlet.ThrowTerminatingError($errorRecord)
}

#endregion OneGet Helpers