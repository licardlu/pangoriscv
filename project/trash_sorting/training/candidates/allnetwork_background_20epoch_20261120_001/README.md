# 暂停交接权重

resume_last.pt 是本轮完成第1轮后保存的完整checkpoint，含学生模型、EMA和AdamW optimizer；第2轮的未保存批次已丢弃。未经本轮评估，不可部署。续训必须保留原始teacher、完整GT、背景损失及BN配置。现有train_four_bins.py没有完整optimizer-resume入口，只把此文件作为--weights会重置优化器和EMA，属于warm start，不能冒称精确续训。详见仓库根目录00_暂停交接_20261120.md。
