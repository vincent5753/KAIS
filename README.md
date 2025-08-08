# KAIS
## 介紹 / Intro
KAIS 是 `Kubernete 自動安裝腳本` 的簡稱，其目標為提供新手更簡易建立叢集的方式，並在過程中保持可以調整不同設置的彈性。 </br>
KAIS is short for `Kubernetes Auto Install Script`, it is made for a more easy way for newbies to install kubernetes while keeping the flexibility to have different choice for setting up the cluster.

目前支援環境\
Current Supported ENVs
|OS \ Arch|amd64(x86_64)|arm64(aarch64)|其他 (other)|最後驗證版本 (Last Verified Version)|
|-|:-:|:-:|:-:|:-:|
|Ubuntu|✅|✅|❌|24@250808|
|Rocky Linux|✅|✅|❌|10@250808|
|RHEL|✅|✅|❌|10@250808|
|Debian|✅|✅|❌|12@250808|
|Arch|To be added|To be added|❌|N/A|


## 使用方式 / Usage
### 裝環境 / Setting up
`latest` 為 `最新版` 安裝方式，腳本命名邏輯為 `$發行版-K8s_latest-$CRI-$CNI`\
`latest` folder is for `latest version` of installations, script naming follows the pattern of `$Disto-K8s_latest-$CRI-$CNI`

快速部署(最新版本) / Deploy in one line(latest version)\

如果你懶得找特定的發行版 (跑這隻通用安裝腳本) / If you are lazy finding you distro info (Run this unified install script)
```
curl https://raw.githubusercontent.com/vincent5753/KAIS/main/latest/Unified-K8s_latest-containerd-flannel.sh | bash
```

作業系統 / OS: `Ubuntu (amd64/arm64)`
```
curl https://raw.githubusercontent.com/vincent5753/KAIS/main/latest/Ubuntu-K8s_latest-containerd-flannel.sh | bash
```

作業系統 / OS: `Rocky Linux / RHEL (amd64/arm64)`
```
curl https://raw.githubusercontent.com/vincent5753/KAIS/refs/heads/main/latest/Rocky_Linux-K8s_latest-containerd-flannel.sh | bash
```

`legacy` 為 `舊版` 安裝方式，腳本命名邏輯為 `$發行版-K8s-$K8s_版本-$CRI-$CNI`\
`legacy` folder is for `old-way` installations, script naming follows the pattern of `$Disto-K8s-$K8s_Version-$CRI-$CNI`

如果你想安裝特定的舊版本\
If you want to install an specifc older version.
```
curl https://raw.githubusercontent.com/vincent5753/KAIS/main/legacy/Ubuntu2404-K8s_1_33-containerd-flannel.sh | bash
```

### 拆環境 / Clean up
快速拆除 / Clean up in one line
```
curl https://raw.githubusercontent.com/vincent5753/KAIS/main/nemesis.sh | bash
```

## 待辦 / TDL
+ 環境偵測(Preflight Detects)
+ 依據參數部署(Deploy using args)
+ 解耦部署(Decoupled Deployment)
+ 自我部署(Self Deploying)
