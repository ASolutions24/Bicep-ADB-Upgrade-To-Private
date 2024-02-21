
var privateDnsZoneName = 'privatelink.azuredatabricks.net'
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

output dnsZone string = privateDnsZone.id
