# Script to install newest containerd (v2.0.2) 
**you can run the script to install containerd,runc and cni-plugin**

**since containerd.io(which maintain by docker) and apt package only support until 1.7.25-1**

**docker-ce will not be installed with this version**

**you can run the script to install**

```bash=
sudo bash Containerd-v2-02-k8s.sh
# or
curl  https://raw.githubusercontent.com/kanic1111/KAIS/main/beta/Containerd-v2-02-k8s.sh | bash
```

>[!Note]
> **The Script has been test to work with Ubuntu22.04 and kubernetes v1.31.5 and should be able to work on ubuntu24.04**

**if you want to have similar enviroment like docker you can already install [nerdctl](https://github.com/containerd/nerdctl) which provide command like docker but are for containrd**
```bash=
wget https://github.com/containerd/nerdctl/releases/download/v2.0.3/nerdctl-2.0.3-linux-amd64.tar.gz
tar Cxzvvf /usr/local nerdctl-2.0.3-linux-amd64.tar.gz
```
