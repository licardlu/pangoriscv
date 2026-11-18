# yolov3_battery
本项目为机器学习大作业充电宝样本不均衡问题提交项目，训练模型为yolov3,
参考原型为https://github.com/eriklindernoren/PyTorch-YOLOv3
本项目提供训练完成的模型及测试文件，不提供训练数据集与训练文件，如有需要，请联系本项目作者

## 准备工作
    $ cd yolov3_battery/
    $ sudo pip3 install -r requirements.txt
    
## 下载模型
    https://bhpan.buaa.edu.cn:443/link/3A5966021CEAA0E120AB3EC426A36673



## 开始测试
使用命令行代码
    $ python3 test.py --weights_path (+下载好的模型路径) --image_path(+测试图片路径) --label_path (+标签路径）
输出结果位于predicted_file文件夹中
   



