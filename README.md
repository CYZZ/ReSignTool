# ReSignTool
这是个ipa包重签名工具

下载源码之后需要
## 1.配置signing的个人开发者证书，或者公司开发证书
![image](https://github.com/CYZZ/ReSignTool/blob/master/images/team.jpg)
## 2.需要将要签名的包进行解压，
在.ipa包的同名文件夹下回生成一个Payload文件夹，
## 3.将描述文件拖拽到Provision
可以点击生成entitlements,在.mobileProvision同名文件夹下回生成plist文件,下次使用的时候不用重新生成，直接拖拽到输入框
## 4.选择开发证书
开发证书需要和描述文件对应
## 5.可以查看当前.ipa包的bundleID可以在修改bundleID（可选）
## 6.点击左下角的重新签名按钮
当出现 task app completed，说明成功了
## 7.在输入框中输入重签之后的文件名以.ipa结尾
## 8.最后直接点击打包就行，
会自动压缩
![image](https://github.com/CYZZ/ReSignTool/blob/master/images/mainAppView.jpg)

可以看到相关的文件结构
![image](https://github.com/CYZZ/ReSignTool/blob/master/images/allStart.jpg)
