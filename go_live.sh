#!/bin/bash

shopt -s expand_aliases

bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
reset=$(tput sgr0)

image_id_default="<your-ami-id>"
instance_type_default="<your-ec2-instance-type>"
security_group_ids_default="<your-security-group-id>"
subnet_id_default="<your-subnet-id>"
key_name_default="<your-ec2-keypair-name>"
region_default="<your-ec2-region-name>"

echo -e "Hi $USERNAME, let's send this live!\n"
read -p "Enter the absolute path for the .pem file(eg-/home/ubuntu/keypair.pem) - " pem_file_path

if ! [[ -f "$pem_file_path" ]]
then
    echo "${bold}${red}ERROR: The path provided is incorrect. Ensure that the .pem file exists at the provided location.${reset}"
    exit 1
fi

# Setup the master EC2 instance
create_ec2_master(){
    echo -e "\n${bold}${blue}##############################\n"
    echo -e "Step 1/6: Master machine setup\n"
    echo -e "##############################${reset}\n"

    read -p "${bold}${green}Provide custom configuration? (y/n)${reset} " choice

    if [[ "$choice" == "y" || "$choice" == "Y" ]]
    then
        read -p "${bold}${green}Enter the instance type (default- $instance_type_default) -${reset} " instance_type
        read -p "${bold}${green}Enter the AMI id (default- $image_id_default) -${reset} " image_id
        read -p "${bold}${green}Enter the security group ids (default- $security_group_ids_default) -${reset} " security_group_ids
        read -p "${bold}${green}Enter the subnet id (default- $subnet_id_default) -${reset} " subnet_id
        read -p "${bold}${green}Enter the key pair name (default- $key_name_default) -${reset} " key_name
        read -p "${bold}${green}Enter the region (default- $region_default) -${reset} " region

        command="aws ec2 run-instances --region $region --image-id $image_id --count 1 --instance-type $instance_type --key-name $key_name --security-group-ids $security_group_ids --subnet-id $subnet_id --output text --query 'Instances[].InstanceId'"
    else
        command="aws ec2 run-instances --region $region_default --image-id $image_id_default --count 1 --instance-type $instance_type_default --key-name $key_name_default --security-group-ids $security_group_ids_default --subnet-id $subnet_id_default --output text --query 'Instances[].InstanceId'"
    fi

    echo "Creating the master instance..."

    master_instance_id=$(eval "$command")
    ip_address=$(aws ec2 describe-instances --region us-east-1 --instance-ids "$master_instance_id" --query "Reservations[].Instances[].PublicIpAddress" --output text)
    echo "${bold}${yellow}The IP address for the master machine is - $ip_address (Note: Copy this as this will be required further ahead)${reset}"

    # 10 second wait so the user can copy the IP address
    sleep 10
    echo 0 "$ip_address"> ~/status_auto_prod.txt
}

# The resuming point will determine the index of function_list from which the execution will start
# This is done to handle cases where the script fails at some point before the entire execution
# status_auto_prod.txt will store the resuming_point index
resuming_point=0

if ! [[ -f ~/status_auto_prod.txt ]]
then
    create_ec2_master
else
    resuming_point=$(awk {'print $1'} ~/status_auto_prod.txt)
    ip_address=$(awk {'print $2'} ~/status_auto_prod.txt)
fi

alias ssh-master="ssh -i $pem_file_path ubuntu@$ip_address"
alias ssh-master-tty="ssh -t -i $pem_file_path ubuntu@$ip_address"
alias scp-master="scp -i $pem_file_path"
alias scp-folder="scp -r -i $pem_file_path"

master="ubuntu@$ip_address"

setup_code_master(){
    echo -e "\n${bold}${blue}######################################\n"
    echo -e "Step 2/6: Code setup on master machine\n"
    echo -e "######################################${reset}\n"

    echo "Cloning the backend repository..."
    ssh-master-tty git clone https://github.com/your-repo.git

    echo "Copying the required .pem files..."
    scp-master "$pem_file_path" "$master":/home/ubuntu/
    
    echo 1 "$ip_address" > ~/status_auto_prod.txt
}

env_setup(){
    echo -e "\n${bold}${blue}##############################################\n"
    echo -e "Step 3/6: Env file setup for master and slaves\n"
    echo -e "##############################################${reset}\n"

    # Write the code for setting up the environment variables that will
    # be used for the production server here

    echo 2 "$ip_address" > ~/status_auto_prod.txt
}

setup_docker_architecture(){
    echo -e "\n${bold}${blue}###################################\n"
    echo -e "Step 4/6: Docker architecture setup\n"
    echo -e "###################################${reset}\n"

    ssh-master-tty sudo docker login

    read -p "${bold}${green}Provide the image tag -${reset} " image_tag

    # Notice the '.' at the end of the docker build command
    # Ensure the DockerFile is in the current directory
    # Or add a cd command to change to the correct directory.
    ssh-master "sudo docker build -t dockerhub-repo:$image_tag ."
    ssh-master "sudo docker push dockerhub-repo:$image_tag"
    ssh-master "sudo docker swarm init && sudo docker network create --driver overlay swarm-network"

    echo 3 "$ip_address" > ~/status_auto_prod.txt
}

handle_slaves(){
    echo -e "\n${bold}${blue}################################\n"
    echo -e "Step 5/6: Slave machine creation\n"
    echo -e "################################${reset}\n"

    read -p "${bold}${green}Enter the number of slaves- ${reset}" slave_count
    read -p "${bold}${green}Enter the slave machine instance type- ${reset}" slave_instance_type
    read -p "${bold}${green}Enter the EBS size (in GB)- ${reset}" ebs_size
    read -p "${bold}${green}Enter the slave prefix- ${reset}" slave_prefix

    echo "Launching the slaves..."
    
    # Write your command to create EC2 instances for the slave machines here

    echo "Slaves launched successfully"
    echo 4 "$ip_address" > ~/status_auto_prod.txt
}

deploy_slaves(){
    echo -e "\n${bold}${blue}########################################\n"
    echo -e "Step 6/6: Deployment of the slave stacks\n"
    echo -e "########################################${reset}\n"

    # Write your command to deploy the slave stack through Docker here

    rm ~/status_auto_prod.txt
}

function_list=(setup_code_master env_setup setup_docker_architecture handle_slaves deploy_slaves)
len=${#function_list[@]}

for func in "${function_list[@]:$resuming_point:$len-$resuming_point}"; do
    $func
done
