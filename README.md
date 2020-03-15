# Brook端口转发一键脚本再次修改版
Brook 端口转发 一键管理脚本再次修改版 基于逗比，yulewang版本修改而来。

去掉了更新之类的功能。删除iptables端口放行规则，更换为全允许。

解决之前脚本不支持CNAME的问题，将DDNS监测周期更换为1min。

-----------------------------------------------------------------------------

## 使用方法
```shell
wget -qO brook-pf-mod.sh https://raw.githubusercontent.com/monret/brook/master/brook-pf-mod.sh && chmod +x brook-pf-mod.sh && bash brook-pf-mod.sh
```
执行结果：
```
  Brook 端口转发 一键管理脚本修改版(DDNS支持) [v1.0.1]  
  1. 安装 Brook
  2. 卸载 Brook
————————————
  3. 启动 Brook
  4. 停止 Brook
  5. 重启 Brook
————————————
  6. 设置 Brook 端口转发
  7. 查看 Brook 端口转发
  8. 查看 Brook 日志
  9. 监控 Brook 运行状态(如果使用DDNS必须打开)
 ————————————
 10. 安装CNAME依赖(若添加DDNS出现异常)
 11. 安装服务脚本(执行安装Brook后请勿重复安装)
 12. iptables一键放行
————————————
 当前状态: 未安装
 请输入数字 [0-12]:
```
按1后回车即可自动安装完成。

**如需开启DDNS支持，请在安装完成后按9开启运行监控。**

## 手动安装
因国内下载github资源速度缓慢，建议国内机器使用手动安装来使用。

根据您的服务器系统版本下载对应版本。(一般都是第一个)
```
https://github.com/txthinking/brook/releases
```
创建并将下载的二进制文件上传到 **/usr/local/brook-pf** 目录

在目录建立 **brook.conf** 和 **brook.log** 两个文件，不要写任何内容。(除非你明白你在做什么)

保证目录下有3个文件后赋予权限：
```
chmod +x /usr/local/brook-pf
```
接下来进入脚本依次执行第10，11，12项。

在执行第11项时可能会出现无法下载的问题，请根据系统类型下载项目内的**brook-pf_debian** 或 **brook-pf_centos**

下载完后改名为 **brook-pf**，上传至 **/etc/init.d/** ，然后执行：
```
chmod +x /etc/init.d/brook-pf
```
Enjoy~
