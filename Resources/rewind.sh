#
# Apigee Lab rewind script
#
# Prerequisites to be set up in the qwiklabs environment:
#
# Roles:
#   roles/container.admin
#
#

#
# Usage. Source the script to retain environment variable values
# . rewind.sh
#

## Collect variables:
## PROJECT_ID ZONE_ID USER_ID


#-----------------------------------------------------------------------
#
# Check input parameters
#
#-----------------------------------------------------------------------
if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    echo "    rewind.sh <labnumber>"
    echo "where labnumber is between 1 for Istio setup and 2 for Apigee setup."
    return 5
fi

LABNUMBER=$1

if [ "$LABNUMBER" -lt 1 -o "$LABNUMBER" -gt 2 ]; then

    echo " Lab number should be between 1 and 2"
    return 2
fi


#-----------------------------------------------------------------------
#
# Lab 1 Setup
#
#-----------------------------------------------------------------------
if [ 1 -le "$LABNUMBER" ]; then

echo -e "\nSetting up Lab 1.\n\n"



export USER_ID=$(gcloud config get-value core/account)

echo "Checking if logged into a gcp account..."

OUTPUT=`gcloud auth list --format json`
if [ "$OUTPUT" = "[]" ]; then
    echo "Please log into a valid student account using"
    echo "    gcloud auth login"
    echo "command."
    return 1
fi

echo "A user is logged in."


#
#
# Configure Project Id
#
export PROJECT_ID=`gcloud projects list --format json | jq -r '.[] | select( .projectId | contains("qwiklabs-gcp-") ) .projectId'`


gcloud config set project $PROJECT_ID

export ZONE_ID=`gcloud compute project-info describe --format=json | jq -r '.commonInstanceMetadata.items[] | select( .key== "google-compute-default-zone") | .value'`

gcloud config set compute/zone $ZONE_ID

gcloud config list


# create gke cluster
gcloud container clusters create apijam \
    --machine-type=n1-standard-2 \
    --num-nodes=6 \
    --no-enable-legacy-authorization \
    --cluster-version=1.8.8-gke.0



kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value core/account)



fi
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
#
# Lab 2 Setup
#
#-----------------------------------------------------------------------
if [ 2 -le "$LABNUMBER" ]; then

echo -e "\nSetting up Lab 2.\n\n"



#
# Test if roles/container.admin is granted to the active user
#
if [ "$(gcloud projects get-iam-policy $PROJECT_ID --format=json | jq -r ".bindings[] | select( .role == \"roles/container.admin\") | .members [] | contains(\"user:$USER_ID\")")" != "true" ]; then
    echo "User $USER_ID is missing required role: roles/container.admin"
    return 1
fi




ISTIO_INSTALL_OUTPUT=$(curl -L https://git.io/getLatestIstio | sh -)

export ISTIO_HOME=$(echo -e "$ISTIO_INSTALL_OUTPUT" | awk "/export PATH=/{ match(\$0, /PATH:(.+)\/bin/ ); print substr(\$0,RSTART+5,RLENGTH-9)}")

export PATH=$PATH:$ISTIO_HOME/bin


cd $ISTIO_HOME

kubectl apply -f ./install/kubernetes/istio-auth.yaml



kubectl create -f <(istioctl kube-inject -f samples/bookinfo/kube/bookinfo.yaml)


istioctl create -f samples/bookinfo/kube/route-rule-all-v1.yaml -n default




fi
#-----------------------------------------------------------------------

# end-of-script

