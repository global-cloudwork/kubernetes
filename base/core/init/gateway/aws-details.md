aws ec2 run-instances --image-id 'ami-0f5fcdfbd140e4ab7' --instance-type 't3.micro' --key-name 'AWS-Key' --block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"Encrypted":false,"DeleteOnTermination":true,"Iops":3000,"SnapshotId":"snap-05fe089b7b96696dd","VolumeSize":20,"VolumeType":"gp3","Throughput":125}}' --network-interfaces '{"AssociatePublicIpAddress":true,"DeviceIndex":0,"Groups":["sg-0c4d7f7079d8f9297"]}' --credit-specification '{"CpuCredits":"standard"}' --network-performance-options '{"BandwidthWeighting":"default"}' --tag-specifications '{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"web-server"}]}' --instance-market-options '{"MarketType":"spot","SpotOptions":{"InstanceInterruptionBehavior":"stop","SpotInstanceType":"one-time"}}' --metadata-options '{"HttpEndpoint":"enabled","HttpPutResponseHopLimit":2,"HttpTokens":"required"}' --private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":true,"EnableResourceNameDnsAAAARecord":false}' --count '1' 





aws ec2 create-security-group --group-name 'launch-wizard-2' --description 'launch-wizard-2 created 2025-12-05T19:35:38.111Z' --vpc-id 'vpc-06103fee5951f7e05' 
aws ec2 authorize-security-group-ingress --group-id 'sg-preview-1' --ip-permissions '{"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"208.96.113.181/32"}]}' 
aws ec2 run-instances --image-id 'ami-0f5fcdfbd140e4ab7' --instance-type 't3.micro' --key-name 'AWS-Key' --block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"Encrypted":false,"DeleteOnTermination":true,"Iops":3000,"SnapshotId":"snap-05fe089b7b96696dd","VolumeSize":20,"VolumeType":"gp3","Throughput":125}}' --network-interfaces '{"AssociatePublicIpAddress":true,"DeviceIndex":0,"Groups":["sg-preview-1"]}' --monitoring '{"Enabled":false}' --credit-specification '{"CpuCredits":"standard"}' --network-performance-options '{"BandwidthWeighting":"default"}' --tag-specifications '{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"cloud-server"}]}' --instance-market-options '{"MarketType":"spot","SpotOptions":{"InstanceInterruptionBehavior":"stop","SpotInstanceType":"one-time"}}' --metadata-options '{"HttpEndpoint":"enabled","HttpPutResponseHopLimit":2,"HttpTokens":"required"}' --placement '{"AvailabilityZoneId":"use2-az1"}' --private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":true,"EnableResourceNameDnsAAAARecord":false}' --count '1' 



aws ec2 run-instances \
    --image-id 'ami-0f5fcdfbd140e4ab7' \
    --instance-type 't3.micro' \
    --key-name 'AWS-Key' \
    --block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"Encrypted":false,"DeleteOnTermination":true,"Iops":3000,"SnapshotId":"snap-05fe089b7b96696dd","VolumeSize":20,"VolumeType":"gp3","Throughput":125}}' \
    --network-interfaces '{"AssociatePublicIpAddress":true,"DeviceIndex":0,"Groups":["sg-preview-1"]}' \
    --monitoring '{"Enabled":false}' \
    --credit-specification '{"CpuCredits":"standard"}' \
    --network-performance-options '{"BandwidthWeighting":"default"}' \
    --tag-specifications '{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"cloud-server"}]}' \
    --instance-market-options '{"MarketType":"spot","SpotOptions":{"InstanceInterruptionBehavior":"stop","SpotInstanceType":"one-time"}}' \
    --metadata-options '{"HttpEndpoint":"enabled","HttpPutResponseHopLimit":2,"HttpTokens":"required"}' \
    --placement '{"AvailabilityZoneId":"use2-az1"}' \
    --private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":true,"EnableResourceNameDnsAAAARecord":false}' \
    --count '1' \
    --user-data '#!/bin/bash
yum update -y
yum install -y git
cd /home/ec2-user
git clone https://github.com/<username>/<repo>.git
cd <repo>
chmod +x startup.sh
./startup.sh'
