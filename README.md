# ftp-fuse

Read and write to a Google Cloud Storage bucket over FTP.

This repo defines a docker container that runs [vsftpd](https://security.appspot.com/vsftpd.html) and [gcs-fuse](https://cloud.google.com/storage/docs/gcs-fuse) to mount a Google Cloud Storage bucket at an FTP server's root directory. It also includes deploy scripts to run the container on Google Compute Engine.

## Requirements

A Google Cloud Services account with billing enabled and some experience running cloud infrastructure.

As of May 2023, the resources defined here will cost approximately $14/month, but prices may vary.

## Usage

This was written to serve as part of a [camera-to-cloud pipeline](https://strickles.photos/blog/shooting-concerts-to-the-cloud-may-30th-2023), to allow photographers using cameras with FTP support to shoot directly to an FTP server that will automatically import images into Adobe Lightroom.

## Startup scripts

```
# Enter your project information below.
# Use a zone / region close to your location.
export PROJECT=my-project
export REGION=us-east4
export ZONE=us-east4-c
export IP_ADDRESS_NAME=ftp-fuse
export FTP_USERNAME=ftp-username
export FTP_BUCKET=ftp-bucket
export SERVICE_ACCOUNT=${projectNumber}-compute@developer.gserviceaccount.com
export DOCKER_IMAGE=$REGION-docker.pkg.dev/$PROJECT/docker/ftp-fuse:latest

gcloud config set project $PROJECT

# Enable APIs
gcloud services enable compute.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com

projectNumber=$(gcloud projects describe $PROJECT --format "value(projectNumber)")

# Build and publish the docker image
docker build -t $DOCKER_IMAGE .
docker push $DOCKER_IMAGE

# Create a secret containing the FTP password
echo -n "my-secret-password" | gcloud secrets create FTP_PASSWORD \
    --data-file=-

# Authorize the service account to read that secret
gcloud secrets add-iam-policy-binding FTP_PASSWORD \
    --member serviceAccount:$SERVICE_ACCOUNT \
    --role roles/secretmanager.secretAccessor

# Create docker registry for the project
gcloud artifacts repositories create docker \
    --repository-format docker \
    --location $REGION

# Create a GCS bucket
gsutil mb gs://$FTP_BUCKET

# Create a reserved IP address for the compute instance
gcloud compute addresses create ftp-fuse \
    --region $REGION

gcloud compute instances create-with-container ftp-fuse \
    --project=$PROJECT \
    --zone=$ZONE \
    --machine-type=e2-small \
    --network-interface=network-tier=PREMIUM,subnet=default,address=https://www.googleapis.com/compute/v1/projects/$PROJECT/regions/$REGION/addresses/$IP_ADDRESS_NAME \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=$SERVICE_ACCOUNT \
    --scopes=https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/trace.append,https://www.googleapis.com/auth/devstorage.full_control,https://www.googleapis.com/auth/cloud-platform \
    --image=projects/cos-cloud/global/images/cos-stable-105-17412-101-13 \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=ftp-fuse \
    --container-image=$DOCKER_IMAGE \
    --container-restart-policy=always \
    --container-privileged \
    --container-env=FTP_USERNAME=$FTP_USERNAME,FTP_BUCKET=$FTP_BUCKET \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=ec-src=vm_add-gcloud,container-vm=cos-stable-105-17412-101-13

# Allow ingress to ports 20, 21 and 40000-40009
gcloud compute --project=$PROJECT firewall-rules create ftp-fuse --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:20,tcp:21,tcp:40000-40009 --source-ranges=0.0.0.0/0
```
