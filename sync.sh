#!/bin/bash

scp /etc/systemd/system/icfs-radosgw.target.wants/icfs-radosgw\@radosgw.gateway.service obj2:/etc/systemd/system/icfs-radosgw.target.wants/icfs-radosgw\@radosgw.gateway.service 
scp /etc/systemd/system/icfs-radosgw.target.wants/icfs-radosgw\@radosgw.gateway.service obj3:/etc/systemd/system/icfs-radosgw.target.wants/icfs-radosgw\@radosgw.gateway.service 

sleep 1
ssh obj1 'systemctl daemon-reload'
echo
ssh obj2 'systemctl daemon-reload'
echo
ssh obj3 'systemctl daemon-reload'
echo

sleep 1
echo "status:---------"
ssh obj1 'systemctl status icfs-radosgw@radosgw.gateway'
echo
ssh obj2 'systemctl status icfs-radosgw@radosgw.gateway'
echo
ssh obj3 'systemctl status icfs-radosgw@radosgw.gateway'
echo

sleep 1
echo "restart:---------"
ssh obj1 'systemctl restart icfs-radosgw@radosgw.gateway'
echo
ssh obj2 'systemctl restart icfs-radosgw@radosgw.gateway'
echo
ssh obj3 'systemctl restart icfs-radosgw@radosgw.gateway'
echo

sleep 1
echo "status:---------"
ssh obj1 'systemctl status icfs-radosgw@radosgw.gateway'
echo
ssh obj2 'systemctl status icfs-radosgw@radosgw.gateway'
echo
ssh obj3 'systemctl status icfs-radosgw@radosgw.gateway'
echo
