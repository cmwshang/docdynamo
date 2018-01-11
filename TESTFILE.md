# Installation Guide - Crunchy Containers for PostgreSQL <br/> Crunchy Data Solutions, Inc.

## Project Setup & Docker Installation

The crunchy-containers can run on different environments including:

- Docker 1.12 

- OpenShift Container Platform 

- Kubernetes 1.5+ 

In this document we list the basic installation steps required for these environments.

These installation instructions are developed and tested for the following operating systems:

- **CentOS 7** 

- **RHEL 7**

### Project Directory Structure

First add the following lines to your .bashrc file to set the project paths:
```
export GOPATH=$HOME/cdev
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN
export CCP_BASEOS=centos7
export CCP_PGVERSION=10
export CCP_PG_FULLVERSION=10.1
export CCP_VERSION=1.7.0
export CCP_IMAGE_PREFIX=crunchydata
export CCP_IMAGE_TAG=$CCP_BASEOS-$CCP_PG_FULLVERSION-$CCP_VERSION
export CCPROOT=$GOPATH/src/github.com/crunchydata/crunchy-containers
export CCP_CLI=kubectl
export NAMESPACE=default
export PV_PATH=/mnt/nfsfileshare
export LOCAL_IP=$(hostname --ip-address)
export REPLACE_CCP_IMAGE_PREFIX=crunchydata
```
It will be necessary to refresh your bashrc file in order for the changes to take effect.
```
. ~/.bashrc
```
Next, set up a project directory structure and pull down the project:
```
mkdir $HOME/cdev $HOME/cdev/src $HOME/cdev/pkg $HOME/cdev/bin
```
At this point, if you are installing crunchy-containers on a CentOS 7 machine, you may continue with the following instructions. If you are doing an installation on RHEL 7, please view the instructions located [below](https://github.com/crunchydata/crunchy-containers/blob/master/docs/install.adoc#rhel-7) that are specific to RHEL environments.

#### CentOS 7
```
cd $GOPATH
sudo yum -y install golang git docker
go get github.com/tools/godep
cd src/github.com
mkdir crunchydata
cd crunchydata
git clone https://github.com/crunchydata/crunchy-containers
cd crunchy-containers
git checkout 1.7.0
godep restore
```
**If you are a Crunchy enterprise customer, you will place the Crunchy repository key and yum repository file into the $CCPROOT/conf directory at this point. These files can be obtained through [https://access.crunchydata.com/](https://access.crunchydata.com/) on the downloads page.**

#### RHEL 7

When setting up the environment on RHEL 7, there are slightly different steps that need to be taken.
```
cd $GOPATH
sudo subscription-manager repos --enable=rhel-7-server-optional-rpms
sudo yum-config-manager --enable rhel-7-server-extras-rpms
sudo yum -y install git golang docker
go get github.com/tools/godep
cd src/github.com
mkdir crunchydata
cd crunchydata
git clone https://github.com/crunchydata/crunchy-containers
cd crunchy-containers
git checkout 1.7.0
godep restore
```
**If you are a Crunchy enterprise customer, you will place the Crunchy repository key and yum repository file into the $CCPROOT/conf directory at this point. These files can be obtained through [https://access.crunchydata.com/](https://access.crunchydata.com/) on the downloads page.**

### Installing PostgreSQL

These installation instructions assume the installation of PostgreSQL 10 through the official PGDG repository. View the documentation located [here](https://wiki.postgresql.org/wiki/YUM_Installation) in order to view more detailed notes or install a different version of PostgreSQL.

Locate and edit your distributions .repo file, located:

- On CentOS: /etc/yum.repos.d/CentOS-Base.repo, [base] and [updates] sections 

- On Red Hat: /etc/yum/pluginconf.d/rhnplugin.conf [main] section 

To the section(s) identified above, you need to append a line (otherwise dependencies might resolve to the PostgreSQL supplied by the base repository):
```
exclude=postgresql*
```
Next, install the RPM relating to the base operating system and PostgreSQL version you wish to install. The RPMs can be found [here](https://yum.postgresql.org/repopackages.php).

For example, to install PostgreSQL 10 on a CentOS 7 system:
```
sudo yum -y install https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm
```
Or to install PostgreSQL 10 on a RHEL 7 system:
```
sudo yum -y install https://download.postgresql.org/pub/repos/yum/testing/10/redhat/rhel-7-x86_64/pgdg-redhat10-10-2.noarch.rpm
```
You'll need to update your system:
```
sudo yum -y update
```
Then, go ahead and install the PostgreSQL server package.
```
sudo yum -y install postgresql10-server.x86_64
```

### Installing Docker

As good practice, at this point you'll update your system.
```
sudo yum -y update
```
After that, it's necessary to add the **docker** group and give your user access to that group (here referenced as **someuser**):
```
sudo groupadd docker
sudo usermod -a -G docker someuser
```
Remember to log out of the **someuser** account for the Docker group to be added to your current session. Once it's added, you'll be able to run Docker commands from your user account.
```
su - someuser
```
You can ensure your **someuser** account is added correctly by running the following command and ensuring **docker** appears as one of the results:
```
groups
```
Before you start Docker, you might consider configuring Docker storage: This is described if you run:
```
man docker-storage-setup
```
Follow the instructions available [on the main OpenShift documentation page](https://docs.openshift.com/container-platform/3.4/install_config/install/host_preparation.html#configuring-docker-storage) to configure Docker storage appropriately.

These steps are illustrative of a typical process for setting up Docker storage. You will need to run these commands as root.

First, add an extra virtual hard disk to your virtual machine (see [this blog post](http://catlingmindswipe.blogspot.com/2012/02/how-to-create-new-virtual-disks-in.html) for tips on how to do so).

Run this command to format the drive, where /dev/sd? is the new hard drive that was added:
```
fdisk /dev/sd?
```
Next, create a volume group on the new drive partition within the fdisk utility:
```
vgcreate docker-vg /dev/sd?
```
Then, you'll need to edit the docker-storage-setup configuration file in order to override default options. Add these two lines to **/etc/sysconfig/docker-storage-setup**:
```
DEVS=/dev/sd?
VG=docker-vg
```
Finally, run the command **docker-storage-setup** to use that new volume group. The results should state that the physical volume /dev/sd? and the volume group docker-vg have both been successfully created.

Next, we enable and start up Docker:
```
sudo systemctl enable docker.service
sudo systemctl start docker.service
```
Verify that Docker version 1.12.6 was installed, as per the OpenShift 3.6 [requirements.](https://docs.openshift.com/container-platform/3.6/install_config/install/host_preparation.html#installing-docker)
```
docker version
```

### Build the Containers

At this point, you have a decision to make - either download prebuilt containers from [Dockerhub](https://hub.docker.com/), **or** build the containers on your local host.

To download the prebuilt containers, make sure you can login to [Dockerhub](https://hub.docker.com/), and then run the following:
```
docker login
cd $CCPROOT
./bin/pull-from-dockerhub.sh
```
Or if you'd rather build the containers from source, perform a container build as follows:
```
cd $CCPROOT
make setup
make all
```
After this, you will have all the Crunchy containers built and are ready for use in a **standalone Docker** environment.

### Configure NFS for Persistence

NFS is required for some of the examples, including the backup and restore containers.

First, if you are running your NFS system with SELinux in enforcing mode, you will need to run the following command to allow NFS write permissions:
```
sudo setsebool -P virt_use_nfs 1
```
Detailed instructions that you can use for setting up a NFS server on Centos 7 are provided in the following link.

[http://www.itzgeek.com/how-tos/linux/centos-how-tos/how-to-setup-nfs-server-on-centos-7-rhel-7-fedora-22.html](http://www.itzgeek.com/how-tos/linux/centos-how-tos/how-to-setup-nfs-server-on-centos-7-rhel-7-fedora-22.html)

**Note**: Most of the Crunchy containers run as the postgres UID (26), but you will notice that when **supplementalGroups** are specified, the pod will include the nfsnobody group in the list of groups for the pod user.

The case of Amazon file systems is different, for that you use the **fsGroup** security context setting but the idea for allowing write permissions is the same.

if you are running your client on a VM, you will need to add _insecure_ to the exportfs file on the NFS server due to the way port translation is done between the VM host and the VM instance.

For more details on this bug, please see the following link.

[http://serverfault.com/questions/107546/mount-nfs-access-denied-by-server-while-mounting](http://serverfault.com/questions/107546/mount-nfs-access-denied-by-server-while-mounting)

A suggested best practice for tuning NFS for PostgreSQL is to configure the PostgreSQL fstab mount options like so:
```
proto=tcp,suid,rw,vers=3,proto=tcp,timeo=600,retrans=2,hard,fg,rsize=8192,wsize=8192
```
Network options:
```
MTU=9000
```
If interested in mounting the same NFS share multiple times on the same mount point, look into the [noac mount option](https://www.novell.com/support/kb/doc.php?id=7010210).

Next, assuming that you are setting up NFS as your storage option, you will need to run the following script:
```
cd $CCPROOT/examples/pv
./create-pv.sh nfs
./create-pvc.sh
```
**Note**: If you elect to configure HostPath or GCE as your storage option, please view README.txt for command-line usage for the ./create-pv.sh command.

## OpenShift Environment

### Installation

See the OpenShift installation guide for details on how to install OpenShift Enterprise on your host. The main instructions are here:

[https://docs.openshift.com/container-platform/3.6/install_config/install/quick_install.html](https://docs.openshift.com/container-platform/3.6/install_config/install/quick_install.html)

**Note:** If you install OpenShift Enterprise on a server with less than `16GB` memory and `40GB` of disk, the following Ansible variables need to be added to `~/.config/openshift/installer.cfg.yml` prior to installation:

``` openshift_check_min_host_disk_gb: _10_ # min 10gb disk openshift_check_min_host_memory_gb: _3_ # min 3gb memory ```

#### System policies for PVC creation/listing

In order to allow the **system** user to be able to create and list persistent volumes using **OpenShift version 3.3+**, you have to enter these commands as the **root** user after installation in order to modify the policies.
```
oc adm policy add-role-to-user cluster-reader system
oc adm policy add-cluster-role-to-user cluster-reader system
oc adm policy add-cluster-role-to-user cluster-admin system
```

### anyuid permissions

One suggested method to use in order to grant a user permission to use the **anyuid** SCC:
```
oc adm policy add-scc-to-group anyuid system:authenticated
```
This says that any authenticated user can run with the anyuid SCC which lets them create PVCs and use the **fsGroup** setting for the PostgreSQL containers to work using NFS.

## Kubernetes Environment

### Installation

See [kubeadm](https://kubernetes.io/docs/setup/independent/install-kubeadm/) for setting up a test environment of Kubernetes.

### Helm

**Installation**

Once you have your Kubernetes environment configured, it is simple to get Helm up and running. Please refer to [this document](https://docs.bitnami.com/kubernetes/get-started-kubernetes/#step-4-install-helm-and-tiller) to get Helm installed and configured properly.

### Permissions

As of Kubernetes 1.6, RBAC security is enabled on most Kubernetes installations. With RBAC, the **postgres-operator** needs permissions granted to it to enable ThirdPartyResources viewing. You can grant the **default** Service Account a cluster role as one way to enable permissions for the operator. This coarse level of granting permissions is not recommended for production. This command will enable the **default** Service Account to have the **cluster-admin** role:
```
kubectl create clusterrolebinding permissive-binding \
        --clusterrole=cluster-admin \
        --user=admin \
        --user=kubelet \
        --group=system:serviceaccounts:default
```

### DNS

Please see [here](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) to view the official documentation regarding configuring DNS for your Kubernetes cluster.

### Google Cloud Environment

The PostgreSQL Container Suite was tested on Google Container Engine.

Here is a link to set up a Kube cluster on GCE: [https://kubernetes.io/docs/getting-started-guides/gce](https://kubernetes.io/docs/getting-started-guides/gce)

Setup the persistent disks using GCE disks by first editing your **bashrc** file and export the GCE settings to match your GCE environment.
```
export GCE_DISK_ZONE=us-central1-a
export GCE_DISK_NAME=gce-disk-crunchy
export GCE_DISK_SIZE=4
export GCE_FS_FORMAT=ext4
```
Then create the PVs used by the examples, passing in the **gce** value as a parameter. This will cause the GCE disks to be created:
```
cd $CCPROOT/examples/pv
./create-pv.sh gce
cd $CCPROOT/examples/pv
./create-pvc.sh
```
Here is a link that describes more information on GCE persistent disk: [https://cloud.google.com/container-engine/docs/tutorials/persistent-disk/](https://cloud.google.com/container-engine/docs/tutorials/persistent-disk/)

To have the persistent disk examples work, you will need to specify a **fsGroup** setting in the **SecurityContext** of each pod script as follows:
```
"securityContext": {
        "fsGroup": 26
        },
```
For our PostgreSQL container, a UID of 26 is specified as the user which corresponds to the **fsGroup** value.

### Tips

Make sure your hostname resolves to a single IP address in your /etc/hosts file. The NFS examples will not work otherwise and other problems with installation can occur unless you have a resolving hostname.

You should see a single IP address returned from this command:
```
hostname --ip-address
```

## Legal Notices

Copyright &copy; 2017 Crunchy Data Solutions, Inc.

CRUNCHY DATA SOLUTIONS, INC. PROVIDES THIS GUIDE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF NON INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

Crunchy, Crunchy Data Solutions, Inc. and the Crunchy Hippo Logo are trademarks of Crunchy Data Solutions, Inc.
