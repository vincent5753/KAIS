# KAIS
## Intro / 介紹
KAIS is short for `Kubernetes Auto Install Script`, it is made for a more easy way for newbies to install kubernetes while keeping the flexibility to have different choice for setting up the cluster. </br>
KAIS 是 `Kubernete 自動安裝腳本` 的簡稱，其目標為提供新手更簡易建立叢集的方式，並在過程中保持可以調整不同設置的彈性。

## Usage / 使用方式
### Setting up / 裝環境
`legacy` 為 `舊版` 安裝方式，腳本命名邏輯為 `$發行版-K8s-$K8s_版本-$CRI-$CNI`  </br>
`legacy` folder is for `old-way` installations, script naming follows the pattern of `$Disto-K8s-$K8s_Version-$CRI-$CNI` </br>

Deploy in one line / 快速部署
```
curl https://raw.githubusercontent.com/vincent5753/KAIS/main/legacy/Ubuntu20-K8s_1_28-containerd-flannel.sh| bash
```

### Tear down(Clean up) / 拆環境
Clean up in one line / 快速拆除
```
curl https://raw.githubusercontent.com/vincent5753/KAIS/main/nemesis.sh | bash
```

## TDL
+ 環境偵測(Preflight Detects)
+ 依據參數部署(Deploy using args)
+ 解耦部署(Decoupled Deployment)
+ 自我部署(Self Deploying)
