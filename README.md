# Azure CycleCloud テンプレート for AI開発ツールとslurmクラスタ

[Azure CycleCloud](https://docs.microsoft.com/en-us/azure/cyclecloud/) はMicrosoft Azure上で簡単にCAE/HPC/Deep Learning用のクラスタ環境を構築できるソリューションです。

Azure CyceCloudのインストールに関しては、[こちら](https://docs.microsoft.com/en-us/azure/cyclecloud/quickstart-install-cyclecloud) のドキュメントを参照してください。

- Anaconda
- Jupyerlab and Jupterhub


## テンプレート詳細
AI開発向けのテンプレートになっています。

以下の構成、特徴を持っています。

1. Slurmジョブスケジューラをschedulerノードにインストール
1. H16r, H16r_Promo, HC44rs, HB60rs, HB120rs_v2などソルバー利用を想定した設定
    - OpenLogic CentOS 7.6 HPC を利用 
1. NFS設定されており、ホームディレクトリが永続ディスク設定。Executeノード（計算ノード）からNFSをマウント
1. MasterノードのIPアドレスを固定設定
    - 一旦停止後、再度起動した場合にアクセスする先のIPアドレスが変更されない
1. 対応ソルバ、フレームワーク

## テンプレートインストール方法

**前提条件:** テンプレートを利用するためには、Azure CycleCloud CLIのインストールと設定が必要です。詳しくは、 [こちら](https://docs.microsoft.com/en-us/azure/cyclecloud/install-cyclecloud-cli) の文書からインストールと展開されたAzure CycleCloudサーバのFQDNの設定が必要です。

1. テンプレート本体をダウンロード
1. 展開、ディレクトリ移動
1. cyclecloudコマンドラインからテンプレートインストール 
   - tar zxvf cyclecloud-iochembd<version>.tar.gz
   - /blobディレクトリにソースコード、およびバイナリを設定します。
         - cd blob
   - cd cyclecloud-ai<number><version>
   - cyclecloud project upload cyclecloud-storage
   - cyclecloud import_template -f templates/slurm-ai<number>.txt
1. 削除したい場合、 cyclecloud delete_template slurm-ai<number>.txt コマンドで削除可能
         
## 利用方法

## 制限事項
1. GPUが利用できるリージョンでの利用を想定しています。東日本リージョンなどが対象です。西日本は対応していません。
1. Azure CycleCloud 8.1.x以降の対応のみです。

***
Copyright Hiroshi Tanaka, hirtanak@gmail.com, @hirtanak All rights reserved.
Use of this source code is governed by MIT license that can be found in the LICENSE file.
