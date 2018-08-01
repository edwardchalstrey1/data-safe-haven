﻿#VM Settings
$publisher = "MicrosoftWindowsServer"
$offer = "WindowsServer"
$sku = "2016-Datacenter"
$vmsize = "Standard_DS2_v2"
$version = "latest"
$osdiskSize = '128'
$osdiskname = "VMNAME_OS_DISK" # Disk with VM name as prefix
$vmname = "VMNAME" # VM Name
$nicname = "VMNAME_NIC1" # VM NIC Name
$ipaddress = "0.0.0.0" # VM internal IP address
$storagediagname = ($vmname.ToLower()+'diag'+(Get-Random))
$storagediagsku = "Standard_LRS"
$diskaccountType = "PremiumLRS"

#Resources
$resourceGroupName = "RESOURCEGROUP" # Resource group for VM
$location = "uk south"

#Select subscription
write-Host -ForegroundColor Cyan "Select the correct subscription..."
$subscription = (
    Get-AzureRmSubscription |
    Sort-Object -Property Name |
    Select-Object -Property Name,Id |
    Out-GridView -OutputMode Single -Title 'Select an subscription'
).name

Select-AzureRmSubscription -SubscriptionName $subscription
write-Host -ForegroundColor Green "Ok, got it!"

Read-Host -Prompt "Check that the subscription has been selected above, press enter key to continue or Ctrl+C to abort"

#Network
$vnetrg = "RESOURCEGROUP" # RG of VNet
$subnetName = "Subnet_Data" # Subnet to attach VM to

#Select VNet
write-Host -ForegroundColor Cyan "Select the correct VNET..."
$vnetname = (
    Get-AzureRmVirtualNetwork -ResourceGroupName $vnetrg |
    Sort-Object -Property Name |
    Select-Object -Property Name,Id |
    Out-GridView -OutputMode Single -Title 'Select the correct VNet'
).name
write-Host -ForegroundColor Green "Ok, got it!"

# Enter credentials for new VM
write-Host -ForegroundColor Green "Enter credentials to be used for VMs local administrator account"
$cred = Get-Credential

# Create Resource Group for DC
write-Host -ForegroundColor Cyan "Creating Resource Group..."
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
write-Host -ForegroundColor Green "Resource Group Created"

# Connect to existing VNET
write-Host -ForegroundColor Cyan "Getting virtual network..."
$vnet = Get-AzureRmVirtualNetwork -Name $vnetname -ResourceGroupName $vnetrg
write-Host -ForegroundColor Green "Got it!"

# Select the subnet
write-Host -ForegroundColor Cyan "Getting subnet..."
$SubnetID = (Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetname -VirtualNetwork $vnet).Id
write-Host -ForegroundColor Green "Got it!"

# Create new NIC in VNET
write-Host -ForegroundColor Cyan "Creating network interface..."
$nic = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName `
      -Name $nicname `
      -SubnetID $subnetID `
      -Location $location `
      -PrivateIpAddress $ipaddress
write-Host -ForegroundColor Green "Network interface created"

#Create managed data disks

#Disk 1 - 20Gb for AD DBs
write-Host -ForegroundColor Cyan "Creating managed disk 1..."
$datadisk1config = New-AzureRmDiskConfig    -Location $location `
                                            -DiskSizeGB 20 `
                                            -AccountType $diskaccountType `
                                            -OsType Windows `
                                            -CreateOption Empty

$datadisk1 = New-AzureRmDisk    -ResourceGroupName $resourceGroupName `
                                -DiskName ($vmname+"_Data_Disk1") `
                                -Disk $datadisk1config
write-Host -ForegroundColor Green "Managed disk 1 created"

#Disk 2 - WSUS
write-Host -ForegroundColor Cyan "Creating managed disk 2..."
$datadisk2config = New-AzureRmDiskConfig    -Location $location `
                                            -DiskSizeGB 256 `
                                            -AccountType $diskaccountType `
                                            -OsType Windows `
                                            -CreateOption Empty

$datadisk2 = New-AzureRmDisk    -ResourceGroupName $resourceGroupName `
                                -DiskName ($vmname+"_Data_Disk2") `
                                -Disk $datadisk2config
write-Host -ForegroundColor Green "Managed disk 2 created"

#Create Storage Account for boot diagnostics
write-Host -ForegroundColor Cyan "Creating diagnostic storage account..."
$storagediag = New-AzureRmStorageAccount -Location $location -Name $storagediagname -ResourceGroupName $resourcegroupname -SkuName $storagediagsku
write-Host -ForegroundColor Green "Diagnostic storage created"

#Create Domain Controller VM
write-Host -ForegroundColor Cyan Creating $vmname ...

$vmConfig = New-AzureRmVMConfig            -VMName $vmName `
                                           -VMSize $vmsize |

       Set-AzureRmVMOperatingSystem        -Windows `
                                           -ComputerName $vmName `
                                           -Credential $cred `
                                           -ProvisionVMAgent `
                                           -EnableAutoUpdate  |

       Set-AzureRmVMSourceImage            -PublisherName $publisher `
                                           -Offer $offer `
                                           -Skus $sku `
                                           -Version $version |

       Set-AzureRmVMOSDisk                 -Name $osdiskname `
                                           -DiskSizeInGB $osdiskSize `
                                           -StorageAccountType $diskaccountType `
                                           -CreateOption fromImage `
                                           -Windows  |

       Add-AzureRmVMDataDisk               -Name $datadisk1.Name `
                                           -CreateOption Attach `
                                           -ManagedDiskId $datadisk1.id `
                                           -Lun 0 |

       Add-AzureRmVMDataDisk               -Name $datadisk2.Name `
                                           -CreateOption Attach `
                                           -ManagedDiskId $datadisk2.id `
                                           -Lun 1 |

       Add-AzureRmVMNetworkInterface       -Id $nic.Id -Primary |

       Set-AzureRmVMBootDiagnostics        -Enable `
                                           -ResourceGroupName $resourcegroupname `
                                           -StorageAccountName $storagediag.StorageAccountName

       New-AzureRmVM                       -ResourceGroupName $resourceGroupName `
                                           -Location $location `
                                           -VM $vmConfig

write-Host -ForegroundColor Green $vmname Complete