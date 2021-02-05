# Adding UAN CAN IPs to IP Reservations in SLS

Adding UAN CAN IPs to IP Reservations in SLS will propogate the data needed for DNS.

1. Get the CAN network SLS data 
   ```bash
   export TOKEN=$(curl -s -k -S -d grant_type=client_credentials -d client_id=admin-client -d client_secret=`kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d` https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token')

   curl -s -k -H "Authorization: Bearer ${TOKEN}" https://api_gw_service.local/apis/sls/v1/networks/CAN|jq > CAN.json
   
   cp CAN.json CAN.json.bak
   ```
2. Edit CAN.json with desired UAN CAN IPs in section .ExtraProperties.Subnets in section where FullName: "CAN Bootstrap DHCP Subnet".
    
   We will be adding to the IPReservations array in the following format in json
   ```json
          {
            "Aliases": [
              "uan10000-can"
            ],
            "IPAddress": "10.103.13.222",
            "Name": "uan10000"
          }
   ```
   **NOTE:** the **-can** goes into the **ALiases** and **hostname** goes in **Name**
3. After adding all the entries desired.  Upload CAN.json to SLS
   ```bash
   curl -s -k -H "Authorization: Bearer ${TOKEN}" --header "Content-Type: application/json" --request PUT --data @CAN.json https://api_gw_service.local/apis/sls/v1/networks/CAN 
   ```
4. In 5 minutes, verify DNS records were created
   ```bash
   nslookup uan10000-can 10.92.100.225
   ```
   Should return 
   ```bash
   Server:		10.92.100.225
   Address:	10.92.100.225#53

   Name:	uan10000-can
   Address: 10.103.13.222
   ```
      ```bash
   nslookup uan10000. 10.92.100.225
   ```
   Should return 
   ```bash
   Server:		10.92.100.225
   Address:	10.92.100.225#53

   Name:	uan10000.can
   Address: 10.103.13.222
   ```