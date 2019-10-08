# GoLive
A bash script to automate setting up the production environment. Includes EC2 instance setup, code deployment, docker stack setup and creation of slave EC2 instances (if required)

The AWS specific variables are defined at the beginning of the file. The values for the same has to be assigned before running the script. Also, there are a few boiler-plate functions which are present to showcase the flow of the script. Feel free to add to its body or remove them.

Aliases have been defined inside the script using shopt -s expand aliases command to handle the frequent SSH and SCP commands.

The status of execution of the script is saved on the secondary storage as a file titled 'status_auto_prod.txt'. This file is both created and removed automatically based on the life-cycle of the script. The motive for the file is to ensure that the script can resume from the last executed point, in case of a failure.
