#!/bin/bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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

echo "INFO Running Posthook for prepare images"
echo "INFO Starting backup of Work Load Managers(WLM)"

###############################################################################
#                              Work Load Managers BackUp                      #
###############################################################################

#maximum retry count
max_retry=5 

#step 1: Backing up Slurm WLM accounting database

result=$(kubectl get pxc -n user slurmdb 2>&1)
if [[ $? -eq 0 ]]; then
    echo "INFO Backing up Slurm WLM accounting database"
    cat <<EOL >backup.yaml
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: slurmdb-backup
spec:
  pxcCluster: slurmdb
  storageName: backup
EOL
    echo "INFO Configuring the Slurm accounting database backup"
    kubectl apply -n user -f backup.yaml 2>&1
    echo "INFO Waiting to start Slurm WLM accounting database backup"
    sleep 60
    #check for slurmdb-backup pxcbackup status
    while true; do
        backup_status=$(kubectl get PerconaXtraDBClusterBackup slurmdb-backup -n user -o=jsonpath='{.status.state}')
        if [[ $backup_status == "Succeeded" ]]; then
            echo "INFO Slurm WLM accounting database backup completed successfully"
            break
        elif [[ $backup_status == "Failed" ]]; then
            echo "ERROR Slurm WLM accounting database backup failed"
            exit 1
        else
            echo "INFO Waiting for Slurm WLM accounting database backup"
        fi
        sleep 30
    done
else
    echo "INFO Slurm WLM is not configured"
fi

#step 2: Backing up Slurm WLM spool directory.

result=$(kubectl get deployment -n user slurmctld 2>&1)
if [[ $? -eq 0 ]]; then
    echo "INFO Backing up Slurm spool directory"
    #scaling down the slurmctld pod replicas
    echo "DEBUG Scaling down slurmctld deployment"
    kubectl scale deployment -n user slurmctld --replicas=0  2>&1
    num_retry=0
    num_replicas=1
    sleep 10
    while [[ ${num_retry} -le ${max_retry}  &&  $num_replicas != 0 ]]; do
        echo "INFO Waiting for slurmctld deployment to scale down"
        sleep 10
        num_retry=$((num_retry + 1))
        num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.spec.replicas}')
    done
    if [[ $num_replicas != 0 ]]; then
        echo "ERROR Failed backing up Slurm spool directory. Unable to scale down slurmctld"
        exit 1
    fi
    echo "DEBUG Successfully scaled down slurmctld deployment"
    slurm_backup=$(find /etc/cray/upgrade/csm/ -name slurm-backup.yaml | sort -r | head -1)
    if [[ -z $slurm_backup ]]; then
        echo "ERROR Failed backing up Slurm spool directory. Unable to find the slurm backup manifest file"
        exit 1
    fi
    echo "DEBUG Creating a slurm-backup pod to backup Slurm spool directory"
    kubectl apply -f $slurm_backup 2>&1
    #checking the status of slurm-backup pod
    namespace="user"
    pod_name="slurm-backup"
    num_retry=0
    pod_status="Pending"
    sleep 10
    while [[ ${num_retry} -le ${max_retry} && $pod_status == "Pending" ]]; do
        echo "INFO Waiting for slurm-backup pod to create"
        sleep 10
        num_retry=$((num_retry + 1))
        pod_status=$(kubectl get pod $pod_name -n $namespace -o=jsonpath='{.status.phase}')
    done
    if [[ $pod_status == "Running" || $pod_status == "Succeeded" ]]; then
        echo "DEBUG slurm-backup pod is now running"
        #saving spool directory contents into archive file
        result=$(kubectl exec -n user slurm-backup -- sh -c 'cd /var/spool/slurm && tar -czf - .' > slurm_spooldir.tar.gz 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "DEBUG Slurm spool directory contents copied successfully"
            result=$(cray artifacts create wlm backups/slurm_spooldir.tar.gz ./slurm_spooldir.tar.gz)
            if [[ $? -eq 0 ]]; then
                echo "INFO Slurm spool directory contents saved in s3 successfully"
                kubectl delete -f $slurm_backup 2>&1
                #checking the status of slurm-backup pod
                # Function to check if the pod exists
                pod_exists() {
                    kubectl get pod $pod_name -n "$namespace" 2>&1
                    return $?
                }
                namespace="user"
                pod_name="slurm-backup"
                num_retry=0
                while [[ ${num_retry} -le ${max_retry}  && $pod_exists ]]; do
                    echo "INFO deletion of $pod_name pod is in-progress"
                    sleep 10
                    num_retry=$((num_retry + 1))
                done
                if pod_exists ; then
                    echo "ERROR Failed backing up Slurm spool directory. Unable to delete slurm-backup pod"
                    kubectl scale deployment -n user slurmctld --replicas=1 2>&1
                    exit 1
                fi
                echo "DEBUG slurm-backup pod is deleted"
                echo "DEBUG Scaling up the slurmctld deployment"
                kubectl scale deployment -n user slurmctld --replicas=1 2>&1
                num_retry=0
                num_replicas=0
                sleep 10
                while [[ ${num_retry} -le ${max_retry} && $num_replicas != 1 ]]; do
                    echo "INFO Waiting for slurmctld deployment to scale up"
                    sleep 10
                    num_retry=$((num_retry + 1))
                    num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.spec.replicas}')
                done
                if [[ $num_replicas != 1 ]]; then
                    echo "ERROR Failed backing up Slurm spool directory. Unable to scale up slurmctld deployment"
                    exit 1
                fi
                echo "INFO Successfully backed up Slurm spool directory"
            else
                echo "ERROR Failed backing up Slurm spool directory. Slurm spool directory not saved in s3"
                kubectl scale deployment -n user slurmctld --replicas=1 2>&1
                kubectl delete -f $slurm_backup 2>&1
                exit 1
            fi
        else
            echo "ERROR Failed backing up Slurm spool directory. Slurm spool directory contents not copied"
            kubectl scale deployment -n user slurmctld --replicas=1 2>&1
            kubectl delete -f $slurm_backup 2>&1
            exit 1
        fi
    else
        echo "ERROR Failed backing up Slurm spool directory. Unable to create slurm-backup pod"
        kubectl scale deployment -n user slurmctld --replicas=1 2>&1
        kubectl delete -f $slurm_backup 2>&1
        exit 1 
    fi
else
    echo "INFO Slurm spool directory is not configured"
fi

#step 3: backing up pbs wlm home directory.

result=$(kubectl get deployment -n user pbs 2>&1)
if [[ $? -eq 0 ]]; then
    echo "INFO Backing up PBS home directory"
    cat <<EOL >pbs-backup.yaml
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
    #Scaling down pbs deployment
    echo "DEBUG Scaling down pbs deployment"
    kubectl scale deployment -n user pbs --replicas=0 2>&1
    num_retry=0
    num_replicas=1
    while [[ ${num_retry} -le ${max_retry}  &&  $num_replicas != 0 ]]; do
        echo "INFO Waiting for pbs deployment to scale down"
        sleep 10
        num_retry=$((num_retry + 1))
        num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.spec.replicas}')
    done
    if [[ $num_replicas != 0 ]]; then
        echo "ERROR Failed backing up PBS home directory. Unable to scale down pbs deployment"
        exit 1
    fi
    echo "DEBUG Successfully scaled down pbs deployment"
    echo "DEBUG Creating a pbs-backup pod to backup PBS home directory"
    kubectl apply -f pbs-backup.yaml 2>&1
    #checking the status of pbs-backup pod
    num_retry=0
    namespace="user"
    pod_name="pbs-backup"
    pod_status="Pending"
    sleep 10
    while [[ ${num_retry} -le ${max_retry} && $pod_status == "Pending" ]]; do
        echo "INFO Waiting for pbs-backup pod to create"
        sleep 10
        num_retry=$((num_retry + 1))
        pod_status=$(kubectl get pod $pod_name -n $namespace -o=jsonpath='{.status.phase}')
    done
    if [[ $pod_status == "Running" || $pod_status == "Succeeded" ]]; then
        #saving pbs directory contents into archive file
        echo "DEBUG pbs-backup pod is now running"
        result=$(kubectl exec -n user pbs-backup -- sh -c 'cd /var/spool/pbs && tar -czf - .' > pbs_home.tar.gz 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "DEBUG PBS home directory contents copied successfully"
            result=$(cray artifacts create wlm backups/pbs_home.tar.gz ./pbs_home.tar.gz  2>&1)
            if [[ $? -eq 0 ]]; then
                echo "INFO PBS home directory contents saved in s3 successfully"
                kubectl delete -f pbs-backup.yaml 2>&1
                #checking the status of pbs-backup pod
                # Function to check if the pod exists
                pod_exists() {
                    kubectl get pod $pod_name -n $namespace 2>&1
                    return $?
                }
                namespace="user"
                pod_name="pbs-backup"
                num_retry=0
                while [[ ${num_retry} -le ${max_retry}  && $pod_exists ]]; do
                    echo "INFO deletion of $pod_name pod is in-progress"
                    sleep 10
                    num_retry=$((num_retry + 1))
                done
                if pod_exists ; then
                    echo "ERROR Failed backing up PBS home directory. Unable to delete pbs-backup pod"
                    kubectl scale deployment -n user pbs --replicas=1 2>&1
                    exit 1
                fi
                echo "DEBUG pbs-backup pod is deleted"
                echo "DEBUG Scaling up the pbs deployment"
                kubectl scale deployment -n user pbs --replicas=1 2>&1
                num_retry=0
                num_replicas=0
                while [[ ${num_retry} -le ${max_retry} && $num_replicas != 1 ]]; do
                    echo "INFO Waiting for pbs deployment to scale up"
                    sleep 10
                    num_retry=$((num_retry + 1))
                    num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.spec.replicas}')
                done
                if [[ $num_replicas != 1 ]]; then
                    echo "ERROR Failed backing up PBS home directory. Unable to scale up pbs deployment"
                    exit 1
                fi
                echo "INFO Successfully backed up PBS home directory"
            else
                echo "ERROR Failed backing up PBS home directory. PBS home directory not saved in s3"
                kubectl scale deployment -n user pbs --replicas=1 2>&1
                kubectl delete -f pbs-backup.yaml 2>&1
                exit 1
            fi
        else
            echo "ERROR Failed backing up PBS home directory. PBS home directory contents not copied"
            kubectl scale deployment -n user pbs --replicas=1 2>&1
            kubectl delete -f pbs-backup.yaml 2>&1
            exit 1
        fi
    else
        echo "ERROR Failed backing up PBS home directory. Unable to create pbs-backup pod"
        kubectl scale deployment -n user pbs --replicas=1 2>&1
        exit 1 
    fi
else
    echo "INFO PBS home directory is not configured"
fi

echo "INFO Posthook for prepare images completed"
