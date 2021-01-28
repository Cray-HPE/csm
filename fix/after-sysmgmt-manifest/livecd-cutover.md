# LiveCD cutover over to Kubernetes Workaround
This is a manual workaround migrate resolv.conf from liveCD to Unbound in Kubernetes

1. Check to see if cray-dhcp-kea, cray-dns-unbound,  cray-sls, cray-smd pods are healthy.

   ```
   kubectl get pods -n services |grep -e kea -e unbound -e sls -e smd|grep -v Running|grep -v Completed
   ```
NOTE: cray-dns-unbound-coredns and cray-dns-unbound-manager may show up as `NotReady` or `Error` and is usually not an issue. 
  

2. Get the service ip for unbound for the NMN network

   ```
   kubectl get services -n services |grep unbound-udp-nmn|awk '{print $4}'
   ```
3. Test Unbound dns resolver. Using unbound at _10.92.100.225_ as an example.
   ```
   nslookup ncn-w001.nmn 10.92.100.225
   ```
4. Run the following 2 commands on all ncn **masters**, **workers**, **storage** nodes and **pit** server. 
Using unbound at _10.92.100.225_ as an example.

   ```
   sed -i 's/NETCONFIG_DNS_STATIC_SERVERS=.*/NETCONFIG_DNS_STATIC_SERVERS=\"'"10.92.100.225"'\"/' /etc/sysconfig/network/config`
   netconfig update -f
   ```
5. On the pit server.  Stop dnsmasq with following command.
   ```
   systemctl stop dnsmasq
   systemctl disable dnsmasq
   ```
