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

  result=$(kubectl apply -n user -f backup.yaml 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "Waiting for 1 minute to start Slurm accounting database backup."
    sleep 60
    while true; do
      backup_status=$(kubectl get pxcbackup slurmdb-backup -n user -o=jsonpath='{.status.phase}')
      if [ "$backup_status" == "Completed" ]; then
        echo "Slurm accounting database Backup completed successfully."
        break
      elif [ "$backup_status" == "Failed" ]; then
        echo "Slurm accounting database Backup failed."
        break
      else
        echo "Backup is still in progress. Status: $backup_status"
      fi		
      sleep 30
    done
  else
    echo "Failed to backup Slurm accounting database. $result"
  fi
else
  echo "Slurm WLM is not present."
fi

#backing up slurm wlm spool directory.

result=$(kubectl get deployment -n user slurmctld 2>&1)
if [[ $? -eq 0 ]]; then
    echo "Backing up Slurm wlm spool directory..."

    result=$(kubectl scale deployment -n user slurmctld --replicas=0 2>&1)
    if [[ $? -eq 0 ]]; then
        num_replicas=$(kubectl get deployment -n user cray-node-slurmctld -o=jsonpath='{.status.replicas}')
        num_retry=0
        while [ $num_replicas != 0 ] && [ "$num_retry" -ne 5 ]; do
            sleep 120
            num_retry=$((num_retry + 1))
            num_replicas=$(kubectl get deployment -n user cray-node-slurmctld -o=jsonpath='{.status.replicas}')
            echo "Waiting for slurmctld pod replicas to scale down..."  
        done
        if [[ $num_replicas -eq 0 ]]; then
            echo "slurmctld pod is stopped."
            #add file directorry
            result=$(kubectl apply -f kubernetes/slurm-backup.yaml 2>&1)
            if [[ $? -eq 0 ]]; then
                #Need to Keep Conditon for Slurm-backup pod Creation
                namespace="user"
                pod_name="slurm-backup"
                while true; do
                    pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
                    if [ "$pod_status" == "Running" ]; then
                        echo "Pod $pod_name is now Running."
                        break
                    elif [ "$pod_status" == "Failed" ]; then
                        echo "Pod $pod_name has failed to start."
                        break
                    else
                        echo "Pod $pod_name is still initializing. Status: $pod_status"
                    fi
                    sleep 10
                done
                
                if [[ "$pod_status" == "Running" ]]; then

                    result=$(kubectl exec -n user slurm-backup –- tar czf - -C /var/spool slurm \ >slurm_spooldir.tar.gz 2>&1)
                    if [[ $? -eq 0 ]]; then
                        echo "spool directory contents copied successfully"

                        result=$(cray artifacts create wlm backups/slurm_spooldir.tar.gz ./slurm_spooldir.tar.gz 2>&1)
                        if [[ $? -eq 0 ]]; then
                            echo "archive saved in s3 successfully"

                            result=$(kubectl delete -f kubernetes/slurm-backup.yaml 2>&1)
                            if [[ $? -eq 0 ]]; then
                                #Need to Keep Conditon for slurm-backup pod is deleted or not
                                namespace="user"
                                pod_name="slurm-backup"

                                # Function to check if the pod exists
                                pod_exists() {
                                kubectl get pod "$pod_name" -n "$namespace" &> /dev/null
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
                                        while [ $num_replicas != 1 ] && [ "$num_retry" -ne 5 ]; do
                                            num_replicas=$(kubectl get deployment -n user cray-node-slurmctld -o=jsonpath='{.status.replicas}')
                                            echo "scaling slurmctld pod replicas to 1."
                                            sleep 60
                                            num_retry=$((num_retry + 1))
                                        done
                                        if [[ $num_replicas -eq 1 ]]; then
                                            echo "slurmctld pod is restarted."
                                        else
                                            echo "Failed Backing up slurm wlm spool directory."
                                        fi
                                    fi
                                done
                            else
                                echo "Failed Backing up slurm wlm spool directory."
                            fi
                        else
                            echo "Failed Backing up slurm wlm spool directory."
                        fi
                    else
                        echo "Failed Backing up slurm wlm spool directory."
                    fi
                else
                    echo "Failed Backing up slurm wlm spool directory."
                fi
            else
                echo "Failed Backing up slurm wlm spool directory."
            fi
        else
            echo "Failed Backing up slurm wlm spool directory."
        fi
    else
      echo "Failed Backing up slurm wlm spool directory."
    fi
else
  echo "slurm spool directory is not present."
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
  echo "Backing up pbs wlm."

  result=$(kubectl scale deployment -n user pbs --replicas=0 2>&1)
  if [[ $? -eq 0 ]]; then
    num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
    num_retry=0
    while [ $num_replicas != 0 ] && [ "$num_retry" -ne 5 ]; do
      num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
      echo "Waiting for slurmctld pod replicas to scale down..."
      sleep 120
      num_retry=$((num_retry + 1))
    done
    if [[ $num_replicas -eq 0 ]]; then
      echo "pbs pod is stopped."

      result=$(kubectl apply -f pbs-backup.yaml 2>&1)
      if [[ $? -eq 0 ]]; then
        namespace="user"
        pod_name="pbs-backup"
        while true; do
          pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o=jsonpath='{.status.phase}')
          if [ "$pod_status" == "Running" ]; then
              echo "Pod $pod_name is now Running."
              break
          elif [ "$pod_status" == "Failed" ]; then
              echo "Pod $pod_name has failed to start."
              break
          else
              echo "Pod $pod_name is still initializing. Status: $pod_status"
          fi
          sleep 10
        done
        if [[ "$pod_status" == "Running" ]]; then
          
          result=$(kubectl exec -n user pbs-backup –- tar czf - -C /var/spool pbs >pbs_home.tar.gz 2>&1)
          if [[ $? -eq 0 ]]; then
            echo "pbs directory contents copied successfully"

            result=$(cray artifacts create wlm backups/pbs_home.tar.gz ./pbs_home.tar.gz 2>&1)
            if [[ $? -eq 0 ]]; then
              echo "archive saved in s3 successfully"

              result=$(kubectl delete -f pbs-backup.yaml 2>&1)
              if [[ $? -eq 0 ]]; then
                #Need to Keep Conditon for pbs-backup pod is deleted or not

                namespace="user"
                pod_name="pbs-backup"

                # Function to check if the pod exists
                pod_exists() {
                  kubectl get pod "$pod_name" -n "$namespace" &> /dev/null
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
                      while [ $num_replicas != 1 ] && [ "$num_retry" -ne 5 ]; do
                        num_replicas=$(kubectl get deployment -n user pbs -o=jsonpath='{.status.replicas}')
                        echo "scaling pbs pod replicas to 1."
                        sleep 120
                        num_retry=$((num_retry + 1))
                      done
                    fi
                    if [[ $num_replicas -eq 0 ]]; then
                      echo "pbs pod is restarted."
                    else
                      echo "Failed Backing up pbs wlm home directory."
                    fi
                    break
                  fi
                  sleep 30
                done
              fi
            else
              echo "Failed Backing up pbs wlm home directory."
            fi
          else
            echo "Failed Backing up pbs wlm home directory."
          fi
        else
          echo "Failed Backing up pbs wlm home directory."
        fi
      else
        echo "Failed Backing up pbs wlm home directory."
      fi
    else
      echo "Failed Backing up pbs wlm home directory."
    fi
  else
    echo "Failed Backing up pbs wlm home directory."
  fi
else
    echo "pbs wlm is not present."
fi