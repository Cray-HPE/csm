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

echo "INFO Running posthook for prepare images"

num_retry=0
max_retry=5

echo "INFO starting Backup of Work Load Managers(WLM)"

###############################################################################
#                              Slurm BackUp                                   #
###############################################################################

#step 1: backing up slurm WLM accounting database

result=$(kubectl get pxc -n user slurmdb 2>&1)
if [[ "$?" -eq 0 ]]; then
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
    echo "DEBUG Waiting for 1 minute to start Slurm accounting database backup"
    sleep 60
    #check for slurmdb-backup pxcbackup status
    while true; do
        backup_status=$(kubectl get PerconaXtraDBClusterBackup slurmdb-backup -n user -o=jsonpath='{.status.state}')
        if [ "$backup_status" == "Succeeded" ]; then
            echo "INFO Slurm accounting database Backup completed successfully"
            break
        elif [ "$backup_status" == "Failed" ]; then
            echo "ERROR Slurm accounting database Backup failed. slurmdb-backup object has failed to start"
            exit 1
        else
            echo "DEBUG Backup is still in progress. Status: $backup_status"
        fi
        sleep 30
    done
else
    echo "INFO Slurm WLM is not present"
fi

#step 2: backing up slurm WLM spool directory.

result=$(kubectl get deployment -n user slurmctld 2>&1)
if [[ $? -eq 0 ]]; then
    echo "INFO Backing up Slurm WLM spool directory"
    echo "DEBUG Scaling down the slurmctld deployment to 0"
    kubectl scale deployment -n user slurmctld --replicas=0
    num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.spec.replicas}')

    #scaling down the slurmctld pod replicas
    while [ "$num_replicas" != 0 ]; do
        num_retry=$((num_retry + 1))
        [ ${num_retry} -ge ${max_retry} ] && {
            echo "ERROR Unable to Scale down deployment slurmctld"
            exit 1
        }
        num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.spec.replicas}')
        echo "DEBUG Waiting for slurmctld pod replicas to scale down"
        sleep 120
    done
    max_retry=0
    cd /etc/cray/upgrade/csm/
    slurm_backup=$(find . -name slurm-backup.yaml | sort -r | head -1)
    if [[ -z "$slurm_backup" ]]; then
        echo "ERROR Failed backing up slurm WLM spool directory: slurm-backup.yaml file is not found"
        exit 1
    fi
    kubectl apply -f $slurm_backup

    namespace="user"
    pod_name="slurm-backup"
    pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')

    #checking the status of slurm-backup pod
    while true; do
        if [ "$pod_status" == "Running" ]; then
            echo "DEBUG Pod $pod_name is now running"
            break
        elif [ "$pod_status" == "Failed" ]; then
            echo "ERROR Failed Backing up slurm WLM home directory: $pod_name  pod has failed to start"
            exit 1
        else
            echo "DEBUG $pod_name pod is still initializing.Re-checking pod status after 10 seconds"
        fi
        sleep 10
        pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
    done

    #saving spool directory contents into archive file
    result=$(kubectl exec -n user slurm-backup -- sh -c 'cd /var/spool/slurm && tar -czf - .' > slurm_spooldir.tar.gz 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "DEBUG slurm spool directory contents copied successfully"
        result=$(cray artifacts create wlm backups/slurm_spooldir.tar.gz ./slurm_spooldir.tar.gz)
        if [[ $? -eq 0 ]]; then
            echo "INFO slurm_spooldir.tar.gz saved in s3 successfully"
            echo "INFO $result"
            kubectl delete -f $slurm_backup
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
                    echo "DEBUG '$pod_name' pod is still running. Deleting"
                else
                    echo "DEBUG '$pod_name' pod has been deleted"
                    result=$(kubectl scale deployment -n user slurmctld --replicas=1 2>&1)
                    num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.spec.replicas}')
                    num_retry=0

                    #scaling up slurmctld deployment
                    while [ "$num_replicas" != 1 ]; do
                        num_retry=$((num_retry + 1))
                        [ ${num_retry} -ge ${max_retry} ] && {
                            echo "ERROR Unable to scale up deployment slurmctld"
                            exit 1
                        }
                        echo "DEBUG Scaling slurmctld pod replicas to 1"
                        num_replicas=$(kubectl get deployment -n user slurmctld -o=jsonpath='{.spec.replicas}')
                        sleep 60
                    done
                    max_retry=0
                    if [[ $num_replicas -eq 1 ]]; then
                        echo "DEBUG Slurmctld pod is restarted"
                    else
                        echo "ERROR Failed Backing up slurm wlm spool directory: slurmctld pod is not restarted"
                        exit 1
                    fi
                    break
                fi
                sleep 10
            done
        else
            echo "ERROR Unable to upload slurm backup tarfile to S3"
            exit 1
        fi
    else
        echo "ERROR Failed backing up slurm wlm spool directory"
        exit 1
    fi
else
    echo "INFO Slurm spool directory is not present"
fi

#step 3: backing up pbs wlm home directory.

result=$(kubectl get deployment -n user pbs 2>&1)
if [[ $? -eq 0 ]]; then
    echo "INFO Backing up pbs WLM"
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
    echo "DEBUG Scaling down the pbs deployment to 0"
    kubectl scale deployment -n user pbs --replicas=0
    num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.spec.replicas}')

    #scaling down pbs deployment
    while [ "$num_replicas" != 0 ]; do
        num_retry=$((num_retry + 1))
        [ ${num_retry} -ge ${max_retry} ] && {
            echo "ERROR Unable to scale down deployment pbs"
            exit 1
        }
        num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.spec.replicas}')
        echo "DEBUG Waiting for pbs pod replicas to scale down"
        sleep 120
    done
    echo "DEBUG pbs pod is stopped by scaling down the replicas to 0"
    kubectl apply -f pbs-backup.yaml
    namespace="user"
    pod_name="pbs-backup"
    pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')

    #checking the status of pbs-backup pod
    while true; do
        if [ "$pod_status" == "Running" ]; then
            echo "DEBUG $pod_name pod is now running"
            break
        elif [ "$pod_status" == "Failed" ]; then
            echo "ERROR Failed backing up pbs wlm home directory: $pod_name pod has failed to start"
            exit 1
        else
            echo "DEBUG $pod_name pod is still initializing. Status: $pod_status"
        fi
        sleep 10
        pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
    done
    if [[ "$pod_status" == "Running" ]]; then
        #saving pbs directory contents into archive file
        result=$(kubectl exec -n user pbs-backup -- sh -c 'cd /var/spool/pbs && tar -czf - .' > pbs_home.tar.gz 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "DEBUG pbs directory contents copied successfully"
            result=$(cray artifacts create wlm backups/pbs_home.tar.gz ./pbs_home.tar.gz )
            if [[ $? -eq 0 ]]; then
                echo "INFO pbs_home.tar.gz saved in s3 successfully"
                echo "INFO $result"
                kubectl delete -f pbs-backup.yaml
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
                        echo "DEBUG '$pod_name' pod is still running. Deleting"
                    else
                        echo "DEBUG '$pod_name' pod has been deleted"
                        result=$(kubectl scale deployment -n user pbs --replicas=1 2>&1)
                        if [[ $? -eq 0 ]]; then
                            num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
                            num_retry=0
                            while [ "$num_replicas" != 1 ] && [ "$num_retry" -ne 5 ]; do
                                num_retry=$((num_retry + 1))
                                num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
                                echo "DEBUG scaling pbs pod replicas to 1"
                                sleep 120
                            done
                        fi
                        if [[ $num_replicas -eq 1 ]]; then
                            echo "DEBUG pbs pod is restarted"
                        else
                            echo "ERROR Failed backing up pbs wlm home directory: pbs pod is not restarted"
                            exit 1
                        fi
                        break
                    fi
                    sleep 30
                done
            else
                echo "ERROR Failed backing up pbs wlm home directory. The pbs backup tar file is not uploaded to the cray artifact"
                exit 1
            fi
        else
            echo "ERROR pbs backup tarfile creation failed"
            exit 1
        fi
    fi
else
    echo "INFO pbs WLM is not present"
fi

echo "INFO posthook for prepare images completed"