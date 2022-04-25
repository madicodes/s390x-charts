import longhorn_client as longhorn

# If automation/scripting tool is inside the same cluster in which Longhorn is installed
# longhorn_url = 'http://longhorn-frontend.longhorn-system/v1'
# If forwarding `longhorn-frontend` service to localhost
# longhorn_url = 'http://localhost:8080/v1'

client = longhorn.Client(url='http://10.161.129.87.nip.io:30514/v1')

# Volume operations
# List all volumes
#volumes = client.list_volume()
#print(volumes)

# # Get volume by NAME/ID
# testvol1 = client.by_id_volume(id="testvol1")
# # Attach TESTVOL1
# testvol1 = testvol1.attach(hostId="worker-1")
# # Detach TESTVOL1
# testvol1.detach()
# # Create a snapshot of TESTVOL1 with NAME
# snapshot1 = testvol1.snapshotCreate(name="snapshot1")
# # Create a backup from a snapshot NAME
# testvol1.snapshotBackup(name=snapshot1.name)
# # Update the number of replicas of TESTVOL1
# testvol1.updateReplicaCount(replicaCount=2)
# # Find more examples in Longhorn integration tests https://github.com/longhorn/longhorn-tests/tree/master/manager/integration/tests
# 
# # Node operations
# # List all nodes
# nodes = client.list_node()
# # Get node by NAME/ID
# node1 = client.by_id_node(id="worker-1")
# # Disable scheduling for NODE1
# client.update(node1, allowScheduling=False)
# # Enable scheduling for NODE1
# client.update(node1, allowScheduling=True)
# # Find more examples in Longhorn integration tests https://github.com/longhorn/longhorn-tests/tree/master/manager/integration/tests
# 
# # Setting operations
# List all settings
# settings = client.list_setting()
# # Get setting by NAME/ID
backupTargetsetting = client.by_id_setting(id="default-replica-count")
# # Update a setting
# backupTargetsetting = client.update(backupTargetsetting, value="1")
# backupTargetsetting = client.update(backupTargetsetting, value="s3://backupbucket@us-east-1/")
# # Find more examples in Longhorn integration tests https://github.com/longhorn/longhorn-tests/tree/master/manager/integration/tests

print(backupTargetsetting)
