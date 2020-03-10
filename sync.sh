#!/bin/bash

scp /usr/lib/systemd/system/icfs-radosgw\@.service obj2:/usr/lib/systemd/system/icfs-radosgw\@.service
scp /usr/lib/systemd/system/icfs-radosgw\@.service obj3:/usr/lib/systemd/system/icfs-radosgw\@.service

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
