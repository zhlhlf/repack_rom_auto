<div align="center">
    <mark>zhlhlf</mark>
</div>

## 补丁
- patch1精简
```
echo "阉割脚本-------------------" ; curl -sL https://raw.githubusercontent.com/zhlhlf/text/main/sys-del_project/coloros14_ql.sh | sudo bash ; 
```
- patch2替换底包
```
wget -q http://47.115.224.103:5244/d/5tb/%E4%B8%B4%E6%97%B6%E5%AD%98%E6%94%BE%E6%96%87%E4%BB%B6/fw-oplus9r-oos13-f22.zip -O asd.zip ; unzip -qo asd.zip ; rm -rf asd.zip ; rm -rf firmware-update/oem_cust1.img ; 
```
```
git clone https://github.com/zhlhlf/android_flash_scripts -b oplus_9r_A as --depth=1 ; cp -r as/* ./ ; rm -r as ;
```

## 如何使用
- 在WSL、ubuntu、deepin等Linux下
```shell
    sudo apt update
    sudo apt upgrade
    sudo apt install git -y
    # 克隆项目
    git clone https://github.com/zhlhlf/repack_rom_auto
    cd repack_rom_auto
    # 安装依赖
    sudo ./bin/setup.sh
    # 开始移植
    sudo ./bin/start.sh <底包路径> <移植包路径>
```
## 感谢
> 本项目使用了以下开源项目的部分或全部内容，感谢这些项目的开发者（排名顺序不分先后）。

- [「BypassSignCheck」by Weverses](https://github.com/Weverses/BypassSignCheck)
- [「contextpatch」 by ColdWindScholar](https://github.com/ColdWindScholar/TIK)
- [「fspatch」by affggh](https://github.com/affggh/fspatch)
- [「gettype」by affggh](https://github.com/affggh/gettype)
- [「lpunpack」by unix3dgforce](https://github.com/unix3dgforce/lpunpack)
- [ 「coloros_port_kebab」 by toraidl ](https://github.com/toraidl/coloros_port_kebab)
- etc
