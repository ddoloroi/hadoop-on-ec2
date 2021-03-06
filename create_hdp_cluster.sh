#!/bin/bash

# Create the ec2 instances
cap production aws:create_ec2_instance \
	private_ip=10.0.2.51 \
	security_group_id=sg-df17ecbb \
	instance_type=t2.medium \
	tag=hadoop-master-node create_public_ip=true 2>&1 | tee hdp.out
cap production aws:create_ec2_instance \
	private_ip=10.0.2.61 \
	security_group_id=sg-df17ecbb \
	instance_type=t2.micro \
	tag=hadoop-data-node-1 create_public_ip=true 2>&1 | tee -a hdp.out
cap production aws:create_ec2_instance \
	private_ip=10.0.2.62 \
	security_group_id=sg-df17ecbb \
	instance_type=t2.micro \
	tag=hadoop-data-node-2 create_public_ip=true 2>&1 | tee -a hdp.out

# Reset ip addresses in production.rb
sed -i "" \
	-e 's/^role \:named_node.*$/role \:named_node, \%w\{master_node_ip\}/g' \
	-e 's/^role \:data_node.*$/role \:data_node, \%w\{data_node_ip\}/g' \
	config/deploy/production.rb
sed -i "" \
	-e 's/^role \:named_node.*$/role \:named_node, \%w\{master_node_ip\}/g' \
	-e 's/^role \:data_node.*$/role \:data_node, \%w\{data_node_ip\}/g' \
	config/deploy/production_hadoop.rb

# Update config/deploy/production.rb
master_ip=$(grep "hadoop-master-node" hdp.out | awk '{print $8}' | tr '\n' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') 
data_nodes_ip=$(grep hadoop-data-node hdp.out | grep -v Creating | awk '{print $8}' | tr '\n' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )

echo "Master Node IP: $master_ip"
echo "Data Node IP: $data_nodes_ip"

sed -i "" -e "s/master_node_ip/${master_ip}/g" -e "s/data_node_ip/${data_nodes_ip}/g" config/deploy/production.rb
sed -i "" -e "s/master_node_ip/${master_ip}/g" -e "s/data_node_ip/${data_nodes_ip}/g" config/deploy/production_hadoop.rb

cap production deploy:yum_update
cap production deploy:install_jdk8
cap production deploy:create_hadoop_user
cap production_hadoop "deploy:setup_auth[10.0.2.51 10.0.2.61 10.0.2.62]"
cap production deploy:install_hadoop hadoop_config_path=/Users/cjavellana/Projects/dbs/hadoop/ec2/hadoop-config
cap production "deploy:update_hostnames[10.0.2.51=hdp.master.node 10.0.2.61=hdp.data.node.1 10.0.2.62=hdp.data.node.2]"
cap production deploy:reboot

