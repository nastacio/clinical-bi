############################################################################# {COPYRIGHT-TOP} ####
#  Copyright 2018 
#  Denilson Nastacio
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
############################################################################# {COPYRIGHT-END} ####

set -e
set +x

curdir=`pwd`
scriptdir=`dirname "${0}"`
scriptname=`basename "${0}"`

aact_dir="${scriptdir}/../../docker/aact"

line="===================================================================================================="

#
# Parameters
#
free_cluster=1

cr_region=us-south
cr_namespace=clinical

cs_name=clinical
cs_location=ams03
cs_nosubnet=true
cs_machine_type=u2c.2x4c
cs_hardware=shared
cs_workerNum=1
cs_publicVlan=
cs_privateVlan=
cs_diskEncryption=false

psql_aact_user=aact
psql_aact_password=azEnrf0aGR4FLczUB
psql_ro_user=readonly
psql_ro_password=readonly

#
# Usage statement
#
function usage() {
    echo "..."
    echo
    echo "Usage: $scriptname [OPTIONS]...[ARGS]"
    echo
    echo " -k  | --apikey             IBM Cloud API key"
    echo "                            See https://console.bluemix.net/docs/iam/apikeys.html#manapikey"
    echo " -i  | --slkey              IBM Cloud Infrastructure key"
    echo "                            See https://console.bluemix.net/docs/containers/cs_cli_reference.html#cs_credentials_set"
    echo " -u  | --sluser             IBM Cloud Infrastructure User"
    echo "                            See https://console.bluemix.net/docs/containers/cs_cli_reference.html#cs_credentials_set"
    echo " -r  | --registry-region    IBM Cloud container registry region, such as us-south or ap-south."
    echo "                            Default is ${cr_region}"
    echo " -s  | --services-region    IBM Cloud cluster services region where the service will be deployed," 
    echo "                            such as us-south or ap-south."
    echo "                            Default is to use the same as the registry region."
    echo " -l  | --services-location  Service location within the services region, such as ams03, par01, fra02."
    echo "                            Default is ${cs_location}"
    echo " -m  | --machine-type       Machine type for the worker nodes."
    echo "                            Default is ${cs_machine_type}"
    echo "     | --tear-down"
    echo "                            Deletes the deployment from cluster services and the image from container registry."           
    echo ""
    echo "       --help      Output this usage statement."
}


#
# Parameters
#
cs_region=${cr_region}
api_key=""
sl_key=""
sl_user=""
tear_down=0
while [[ $# > 0 ]]
do
key="$1"
shift
case $key in
    -k|--apikey)
    api_key=$1
    shift
    ;;
    -i|--slkey)
    free_cluster=0
    sl_key=$1
    shift
    ;;
    -u|--sluser)
    free_cluster=0
    sl_user=$1
    shift
    ;;
    -r|--registry-region)
    cr_region=$1
    shift
    ;;
    -s|--services-region)
    cs_region=$1
    shift
    ;;
    -l|--services-location)
    cs_location=$1
    shift
    ;;
    -m|--machine-type)
    cs_machine_type=$1
    shift
    ;;
    -t|--tear-down)
    tear_down=1
    ;;
    -h|--help)
    usage
    exit
    ;;
    -v|--verbose)
    verbose=1
    ;;
    *)
    echo "Unrecognized parameter: $key"
    usage
    exit 1
esac
done

#
# Parameter checks
#
if [ "${api_key}"  == "" ]
then
    echo "ERROR: Missing IBM Cloud API Key"
    echo "Refer to https://console.bluemix.net/docs/iam/apikeys.html"
    usage
    exit 2
fi
if [ ${free_cluster} -eq 0 ]
then
    if [ "${sl_key}" == "" ] || [ "${sl_user}" == "" ]
    then 
        echo "ERROR: When infrastructure user or key are specified, both parameters are mandatory."
        echo "Refer to https://console.bluemix.net/docs/containers/cs_cli_reference.html#cs_credentials_set."
        usage
        exit 3
    fi
fi

echo $line
echo Verifying presence and configuration of IBM Cloud CLI
echo $line


which bx > /dev/null || 
    (echo "IBM Cloud CLI not installed"
     echo "Refer to https://console.bluemix.net/docs/cli/reference/bluemix_cli/get_started.html"
     exit 4)

(bx plugin list | grep container-registry) || \
    bx plugin install container-registry -r Bluemix || \
        (echo "Unable to install container-registry plugin on IBM Cloud CLI"
         exit 5)

(bx plugin list | grep container-service) || \
    bx plugin install container-service -r Bluemix || \
        (echo "Unable to install container-service plugin on IBM Cloud CLI"
         exit 5)

which docker > /dev/null || 
    (echo "docker CLI not installed"
     echo "Refer to https://docs.docker.com/install/"
     exit 6)

which kubectl > /dev/null || 
    (echo "kubectl CLI not installed"
     echo "Refer to https://kubernetes.io/docs/tasks/tools/install-kubectl/"
     exit 6)

echo
echo
echo $line
echo Authenticating API keys with IBM Cloud
echo $line

bx_output=$(mktemp -t bxlogin).txt
bx login --apikey ${api_key} --check-version=false > "${bx_output}" 2>&1 || \
    (cat "${bx_output}"
     rm "${bx_output}"
     echo "Unable to authenticate IBM Cloud API Key"
     echo "Refer to https://console.bluemix.net/docs/iam/apikeys.html for instructions"
     exit 7) 

if [ ${free_cluster} -eq 0 ]
then
    bx cs credentials-set --infrastructure-username ${sl_user} --infrastructure-api-key ${sl_key}
fi

bx cr region-set ${cr_region} || \
    (echo "Unrecognized cloud registry region [${cr_region}]. Available regions are:"
     echo EOF | bx cr region-set
     exit 8)

cr_registry_url=$(bx cr region | grep registry\. | cut -d "'" -f 4)
image_name=${cr_registry_url}/"${cr_namespace}"/aact:latest

if [ ${tear_down} -eq 0 ]
then
    echo $line
    echo "Creating image in container registry region ${cr_region}"
    echo $line

    (bx cr namespace-list | grep "${cr_namespace}") || \
     bx cr namespace-add "${cr_namespace}" || \
         (echo "Unable to create namespace ${cr_namespace}"
          exit 8)

    bx cr image-inspect "${image_name}" > /dev/null 2>&1 ||
        (echo "Building image (this make take a few minutes)"
         bx cr build --tag ${image_name} "${aact_dir}")

    echo
else
    echo $line
    echo "Deleting image from container registry region ${cr_region}"
    echo $line
    bx_output=$(mktemp -t cluster).txt
    bx cr image-inspect ${image_name} > "${bx_output}" 2>&1 && \
    (
        cat "${bx_output}"
        rm -f "${bx_output}"

        bx cr image-rm ${image_name}
    )
    echo
fi


if [ ${tear_down} -eq 0 ]
then
    # https://console.bluemix.net/docs/containers/cs_cli_reference.html
    echo $line
    echo Deploying image in container services region ${cs_region}
    echo $line
    
    bx cs region-set ${cs_region} || \
        (echo "Unrecognized cloud services region [${cs_region}]. Available regions are:"
         bx cs regions
         exit 9)
    
    create_cluster=0
    bx cs cluster-get ${cs_name} > /dev/null 2>&1 || create_cluster=1
    echo
    if [ ${create_cluster} -eq 1 ]; then 
        if [ ${free_cluster} -eq 1 ]; then
            bx cs cluster-create --name ${cs_name}
        else
            bx cs cluster-create \
            --name ${cs_name} \
            --location ${cs_location} \
            --hardware ${cs_hardware} \
            --machine-type ${cs_machine_type} \
            --no-subnet \
            --workers 1 \
            --disable-disk-encrypt
        fi
    else
        echo "Found cluster ${cs_name}. Skipping creation."
    fi
    
    not_ready=0
    (bx cs cluster-get ${cs_name} | grep "State.*normal" > /dev/null ) || not_ready=1
    if [ ${not_ready} -eq 1 ]
    then 
        echo "Waiting for cluster deployment to complete"
        echo "(this may take several minutes)"
        while [ ${not_ready} -eq 1 ]
        do
           sleep 20
           not_ready=0
           (bx cs cluster-get ${cs_name} | grep "State.*normal" > /dev/null) || not_ready=1
        done
        echo "Deployment complete"
        bx cs cluster-get ${cs_name}
    fi

    echo
    echo "Cluster workers"
    echo
    (bx cs workers ${cs_name} --json | grep "status.*Ready" > /dev/null 2>&1) || \
       (bx cs workers ${cs_name}
        echo "No workers in Ready state"
        exit 9)
    bx cs workers ${cs_name}
    
    # TO-DO: Find out the internal bx cr token-list structure to use go template to get the token id without grep and cut
    token_id=$(bx cr token-list --format "{{.}}" | grep "Token for clinical deployment" | head -n 1 | cut -d "{" -f 2 | cut -d " " -f 1)
    if [ "${token_id}" == "" ]
    then 
        bx cr token-add --description "Token for ${cs_name} deployment" --non-expiring --readwrite
        token_id=$(bx cr token-list --format "{{.}}" | grep "Token for clinical deployment" | head -n 1 | cut -d "{" -f 2 | cut -d " " -f 1)
    fi
    
    docker_token=$(bx cr token-get ${token_id} | grep -v identifier | grep Token | tr -s " " | cut -d " " -f 2)
    
    kubectl_config=$(bx cs cluster-config clinical | grep export | cut -d "=" -f 2)
    export KUBECONFIG="${kubectl_config}"
    bx cs cluster-config clinical

    k8secret=$(mktemp -t k8secret).yml
    b64_aact_user=$(echo -n "${psql_aact_user}" | base64)
    b64_aact_password=$(echo -n "${psql_aact_password}" | base64)
    sed "s#%%secret%%#aact-secret#g" "${scriptdir}/k8secret.yml.template" > "${k8secret}"
    sed -ibak "s#%%user%%#${b64_aact_user}#g" "${k8secret}"
    sed -ibak "s#%%password%%#${b64_aact_password}#g" "${k8secret}"
    kubectl get secret aact-secret > /dev/null 2>&1 && kubectl delete secret aact-secret
    kubectl --namespace default create -f "${k8secret}"
    rm -f "${k8secret}"

    b64_ro_user=$(echo -n "${psql_ro_user}" | base64)
    b64_ro_password=$(echo -n "${psql_ro_password}" | base64)
    sed "s#%%secret%%#ro-secret#g" "${scriptdir}/k8secret.yml.template" > "${k8secret}"
    sed -ibak "s#%%user%%#${b64_ro_user}#g" "${k8secret}"
    sed -ibak "s#%%password%%#${b64_ro_password}#g" "${k8secret}"
    kubectl get secret ro-secret > /dev/null 2>&1 && kubectl delete secret ro-secret
    kubectl --namespace default create -f "${k8secret}"
    rm -f "${k8secret}"
    
    k8_secret_name=clinical.sample.com
    kubectl get secret ${k8_secret_name} > /dev/null 2>&1 ||
       (kubectl --namespace default create secret docker-registry ${k8_secret_name} --docker-server=${cr_registry_url} --docker-username=token --docker-password=${docker_token} --docker-email=fictional@docker.com)

    k8yaml=$(mktemp -t k8deploy).yml
    sed "s#%%image_name%%#${image_name}#g" "${scriptdir}/k8deploy.yml.template" > "${k8yaml}"
    sed -ibak "s#%%image_pull_secret%%#${k8_secret_name}#g" "${k8yaml}"
    sed -ibak "s#%%aact_password%%#${psql_aact_password}#g" "${k8yaml}"

    cat ${k8yaml}
    kubectl apply -f ${k8yaml}
    rm -f ${k8yaml}

    kubectl get deployments
    kubectl get pods
    kubectl get services
    bx cs workers  clinical

    echo
    echo ${line}
    echo "Token for kubectl proxy"
    echo ${line}
    echo
    echo "Launch 'kubectl proxy', then open the following URL on your browser"
    echo "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/overview?namespace=default"
    echo
    echo "Use the following token for authentication"
    echo $(kubectl config view -o jsonpath='{.users[0].user.auth-provider.config.id-token}')
    echo

    echo
    echo ${line}
    echo "postgresql connection information"
    echo ${line}
    public_ip=$(bx cs workers clinical --json | grep publicIP | cut -d "\"" -f 4)
    public_port=$(kubectl get service aact-service -o jsonpath='{.spec.ports[0].nodePort}')
    echo "psql -h ${public_ip} -p ${public_port} -d aact -U ${psql_ro_user} -W"
    echo "Password is: ${psql_ro_password}"
    echo

    echo
    echo ${line}
    echo "adminer connection information"
    echo ${line}
    adminer_public_port=$(kubectl get service adminer-service -o jsonpath='{.spec.ports[0].nodePort}')
    echo "http://${public_ip}:${adminer_public_port}/?pgsql=${public_ip}%3A${public_port}&username=readonly&db=aact&ns=public"
    echo "Password is: ${psql_ro_password}"
    echo
else
    echo $line
    echo "Deleting deployment ${cs_name} from cluster ${cs_name}"
    echo $line

    kubectl get deployment ${cs_name} > /dev/null 2>&1 && kubectl delete deployment ${cs_name}
    kubectl get service aact-service > /dev/null 2>&1 && kubectl delete service aact-service
    kubectl get secret aact-secret > /dev/null 2>&1 && kubectl delete secret aact-secret
    kubectl get secret ro-secret > /dev/null 2>&1 && kubectl delete secret ro-secret

    echo
    echo "The cluster ${cs_name} is not deleted by this operation."
    echo "Execute 'bx cs cluster-rm ${cs_name}' if you want to delete the cluster."

    echo "Tear down complete"
fi
