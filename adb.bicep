param disablePublicIp bool = true
param publicNetworkAccess string = 'Enabled'

@description('Indicates whether to retain or remove the AzureDatabricks outbound NSG rule - possible values are AllRules or NoAzureDatabricksRules.')
@allowed([
  'AllRules'
  'NoAzureDatabricksRules'
])
param requiredNsgRules string = 'AllRules'

@description('Location for all resources.')
param location string //= resourceGroup().location

param pricingTier string = 'premium'

@description('The name of the public subnet to create.')
param publicSubnetName string = 'sn-dbw-public'

@description('The name of the private subnet to create.')
param privateSubnetName string = 'sn-dbw-private'

@description('Virtual Network subnet name')
param PrivateEndpointSubnetName string = 'sn-dbw-private-ep'

param vnetResourceGroupName string = 'rg-sec-dbw-prod'

param vnetName string = 'vnet-sec-dbw-prod'

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  name: PrivateEndpointSubnetName
  parent: vnet
}
output subnetid string = subnet.id


@description('The name of the Azure Databricks workspace to create.')
param workspaceName string

var managedResourceGroupName = 'databricks-rg-${workspaceName}-${uniqueString(workspaceName, resourceGroup().id)}'
var trimmedMRGName = substring(managedResourceGroupName, 0, min(length(managedResourceGroupName), 90))
var managedResourceGroupId = '${subscription().id}/resourceGroups/${trimmedMRGName}'


var privateEndpointName = '${workspaceName}-pvtEndpoint'
var privateEndpointBrowserAuthName = '${workspaceName}-BrowserpvtEndpoint'
var privateDnsZoneName = 'privatelink.azuredatabricks.net'
var pvtEndpointDnsGroupName = '${privateEndpointName}/mydnsgroupname'
var pvtEndpointBrowserAuthDnsGroupName = '${privateEndpointBrowserAuthName}/mydnsgroupname'


resource symbolicname 'Microsoft.Databricks/workspaces@2023-02-01' = {
  name: workspaceName
  location: location
  sku: {
    name: pricingTier
  }
  properties: {
    managedResourceGroupId: managedResourceGroupId
    parameters: {
      customVirtualNetworkId: {
        value: vnet.id
        //value: '/subscriptions/2f054702-74ef-49dc-8055-920692478b36/resourceGroups/rg-sec-dbw-prod/providers/Microsoft.Network/virtualNetworks/vnet-sec-dbw-prod'
      }
      customPublicSubnetName: {
        value: publicSubnetName
      }
      customPrivateSubnetName: {
        value: privateSubnetName
      }
      enableNoPublicIp: {
        value: disablePublicIp
      }
    }
    publicNetworkAccess: publicNetworkAccess
    requiredNsgRules: requiredNsgRules
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, PrivateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: symbolicname.id
          groupIds: [
            'databricks_ui_api'
          ]
        }
      }
    ]
  }
}

resource privateBrowserEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: privateEndpointBrowserAuthName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, PrivateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointBrowserAuthName
        properties: {
          privateLinkServiceId: symbolicname.id
          groupIds: [
            'browser_authentication'
          ]
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}


var HubSubscriptionID = '39aca73e-1d25-4edf-84d5-ebe0397a816b'
var dnszoneRG = 'rg-sec-dbw-hub'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
  scope:resourceGroup(HubSubscriptionID,dnszoneRG)
  /*location: 'global'
  dependsOn: [
    privateEndpoint
  ]
  */
}

/*
resource privateDnsZoneName_privateDnsZoneName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}
*/

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-12-01' = {
  name: pvtEndpointDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}

resource pvtEndpointBrowserDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-12-01' = {
  name: pvtEndpointBrowserAuthDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint,privateBrowserEndpoint,pvtEndpointDnsGroup
  ]
}

