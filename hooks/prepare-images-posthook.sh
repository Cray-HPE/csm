#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

num_retry=0
max_retry=5
echo "starting Backup of Work Load Managers."

#Slurm BackUp

#backing up slurm wlm accounting database.
result=$(kubectl get pxc -n user slurmdb 2>&1)
if [[ "$?" -eq 0 ]]; then
    echo "Backing up Slurm WLM accounting database."
    cat <<EOL > backup.yaml
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: slurmdb-backup
spec:
  pxcCluster: slurmdb
  storageName: backup
EOL
echo "Configuring the Slurm accounting database backup..."

# Should we provide the complete path of backup.yaml???
kubectl apply -n user -f backup.yaml 2>&1
echo "Waiting for 1 minute to start Slurm accounting database backup."
sleep 60
while true; do
    backup_status=$(kubectl get pxcbackup slurmdb-backup -n user -o=jsonpath='{.status.phase}')
    if [ "$backup_status" == "Completed" ]; then
        echo "Slurm accounting database Backup completed successfully."
        break
    elif [ "$backup_status" == "Failed" ]; then
        echo "Slurm accounting database Backup failed."
        exit 1
    else
        echo "Backup is still in progress. Status: $backup_status"
    fi
    sleep 30
done
else
    echo "Slurm WLM is not present."
fi

#backing up slurm wlm spool directory.

result=$(kubectl get deployment -n user slurmctld 2>&1)
if [[ $? -eq 0 ]]; then
    echo "Backing up Slurm wlm spool directory..."
    echo "Scaling down the slurmctld deployment to 0"
    kubectl scale deployment -n user slurmctld --replicas=0
    num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.status.replicas}')
    while [ "$num_replicas" != 0 ]; do
            num_retry=$((num_retry + 1))
            [ ${num_retry} -ge ${max_retry} ] && { echo "Scaling of the slurmctld deployment to zero failed. Pls check it manually"; exit 1; }
            num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.status.replicas}')
            echo "Waiting for slurmctld pod replicas to scale down..." 
            sleep 120 
    done
    echo "slurmctld pod is stopped by scaling down the replicas to 0."
    cd /etc/cray/upgrade/csm/media
    slurm_backup=$(find . -name slurm-backup.yaml  | sort -r |head -1)
    if [[ $? -ne 0 ]]; then
        echo "Failed Backing up slurm wlm spool directory: slurm-backup.yaml file is not found."
        exit 1
    fi
    kubectl apply -f $slurm_backup
    #Need to Keep Conditon for Slurm-backup pod Creation
    namespace="user"
    pod_name="slurm-backup"
    pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
    while true; do
        if [ "$pod_status" == "Running" ]; then
            echo "Pod $pod_name is now Running."
            break
        elif [ "$pod_status" == "Failed" ]; then
            echo "Failed Backing up pbs wlm home directory: Pod $pod_name has failed to start."
            exit 1
        else
            echo "Pod $pod_name is still initializing.Re-checking pod status after 10 seconds."
        fi
        sleep 10
        pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
    done
    result=$(kubectl exec -n user slurm-backup –- tar czf - -C /var/spool slurm \ >slurm_spooldir.tar.gz 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "spool directory contents copied successfully"
        result=$(cray artifacts create wlm backups/slurm_spooldir.tar.gz ./slurm_spooldir.tar.gz 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "archive saved in s3 successfully"
            kubectl delete -f $slurm_backup
            #Need to Keep Conditon for slurm-backup pod is deleted or not
            namespace="user"
            pod_name="slurm-backup"
            # Function to check if the pod exists
            pod_exists() {
                kubectl get pod "$pod_name" -n "$namespace" 2>&1
                return $?
            }
            # Check and delete the pod in a loop
            while true; do
                if pod_exists; then
                    echo "Pod '$pod_name' is still running. Deleting..."
                else
                    echo "Pod '$pod_name' has been deleted."
                    result=$(kubectl scale deployment -n user slurmctld --replicas=1 2>&1)
                    num_replicas=$(kubectl get deployment -n user cray-node-slurmctld -o=jsonpath='{.status.replicas}')
                    num_retry=0
                    while [ "$num_replicas" != 1 ]; do
                        num_retry=$((num_retry + 1))
                        num_replicas=$(kubectl get deployment -n user cray-node-slurmctld -o=jsonpath='{.status.replicas}')
                        [ ${num_retry} -ge ${max_retry} ] && { echo "Scaling of the slurmctld deployment to one failed. Pls check it manually"; exit 1; }
                        echo "scaling slurmctld pod replicas to 1."
                        sleep 60
                    done
                    if [[ $num_replicas -eq 1 ]]; then
                        echo "slurmctld pod is restarted."
                    else
                        echo "Failed Backing up slurm wlm spool directory: slurmctld pod is not restarted."
                        exit 1
                    fi
                    break
                fi
                sleep 10
            done
        else
            echo "Failed Backing up slurm wlm spool directory. The slurm backup tar file is not uploaded to the cray artifact.$result"
            exit 1
        fi
    else
        echo "Failed Backing up slurm wlm spool directory. The slurm backup tar file creation failed.$result"
        exit 1
    fi
else
    echo "Slurm spool directory is not present."
fi

#backing up pbs wlm home directory.

result=$(kubectl get deployment -n user pbs 2>&1)
if [[ $? -eq 0 ]]; then
    echo "Backing up pbs WLM."
    cat <<EOL > pbs-backup.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pbs-backup
  namespace: user
spec:
  containers:
    - name: pbs-backup
      image: dtr.dev.cray.com/baseos/busybox:1.31.1
      command:
        - /bin/sleep
        - infinity
      volumeMounts:
        - name: pbs-data
          mountPath: /var/spool/pbs
  volumes:
    - name: pbs-data
      persistentVolumeClaim:
        claimName: pbs-data
EOL
# Should we add a check for the pbs deployment existence check similar to slurm??
echo "Backing up pbs wlm."
echo "Scaling down the pbs deployment to 0"
kubectl scale deployment -n user pbs --replicas=0 
num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
    while [ "$num_replicas" != 0 ] ; do
        num_retry=$((num_retry + 1)) 
        [ ${num_retry} -ge ${max_retry} ] && { echo "Scaling of the pbs deployment to zero failed. Pls check it manually"; exit 1; }
        num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
        echo "Waiting for slurmctld pod replicas to scale down..."
        sleep 120
    done
    echo "pbs pod is stopped by scaling down the replicas to 0."
    # should we add the complete path of the pbs-backup.yaml??
    kubectl apply -f pbs-backup.yaml
    namespace="user"
    pod_name="pbs-backup"
    pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
    while true; do
       if [ "$pod_status" == "Running" ]; then
          echo "Pod $pod_name is now Running."
          break
       elif [ "$pod_status" == "Failed" ]; then
          echo "Failed Backing up pbs wlm home directory: Pod $pod_name has failed to start."
          exit 1
       else
          echo "Pod $pod_name is still initializing. Status: $pod_status"
       fi
       sleep 10
       pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
    done
    if [[ "$pod_status" == "Running" ]]; then
        result=$(kubectl exec -n user pbs-backup –- tar czf - -C /var/spool pbs >pbs_home.tar.gz 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "pbs directory contents copied successfully"
            result=$(cray artifacts create wlm backups/pbs_home.tar.gz ./pbs_home.tar.gz 2>&1)
            if [[ $? -eq 0 ]]; then
                echo "archive saved in s3 successfully"
                kubectl delete -f pbs-backup.yaml 
                #Need to Keep Conditon for pbs-backup pod is deleted or not
                namespace="user"
                pod_name="pbs-backup"
                # Function to check if the pod exists
                pod_exists() {
                    kubectl get pod "$pod_name" -n "$namespace" 2>&1
                    return $?
                }
                # Check and delete the pod in a loop
                while true; do
                    if pod_exists; then
                        echo "Pod '$pod_name' is still running. Deleting..."
                    else
                        echo "Pod '$pod_name' has been deleted."
                        result=$(kubectl scale deployment -n user pbs --replicas=1 2>&1)
                        if [[ $? -eq 0 ]]; then
                            num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
                            num_retry=0
                            while [ "$num_replicas" != 1 ] && [ "$num_retry" -ne 5 ]; do
				num_retry=$((num_retry + 1))
                                num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
                                echo "scaling pbs pod replicas to 1."
                                sleep 120
                            done
                        fi
                            if [[ $num_replicas -eq 0 ]]; then
                                echo "pbs pod is restarted."
                            else
                                echo "Failed Backing up pbs wlm home directory: pbs pod is not restarted."
                                exit 1
                            fi
                            break
                    fi
                    sleep 30
                done
            else
                echo "Failed Backing up pbs wlm home directory. The pbs backup tar file is not uploaded to the cray artifact.$result"
                exit 1
            fi
        else
            echo "Failed Backing up pbs wlm home directory. The pbs backup tar file creation failed. $result"
            exit 1
        fi
        fi
else
    echo "pbs wlm is not present."
fi
