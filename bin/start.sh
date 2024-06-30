#!/bin/bash

work_dir=$(pwd)
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)
export PATH=$PATH:$(pwd)/bin/pys:$(pwd)/bin/$(uname)/$(uname -m)/
chmod 777 * -R

# 导入环境变量
. ./config

# Import functions
. ./bin/functions.sh

blue "正在清理文件" "Cleaning up.."
for i in ${port_partition};do
    [ -d ./${i} ] && rm -rf ./${i}
done
rm -rf app tmp baserom portrom out

green "文件清理完毕" "Files cleaned up."

mkdir -p baserom/images portrom/images out/images out/firmware-update

# 底包和移植包为外部参数传入
baseromUrl="$1"
portromUrl="$2"

baserom=base.rom
portrom=port.rom

shopt -s expand_aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
    yellow "检测到Mac，设置alias" "macOS detected,setting alias"
    alias sed=gsed
    alias tr=gtr
    alias grep=ggrep
    alias du=gdu
    alias date=gdate
    #alias find=gfind
fi

check unzip aria2c 7z zip java zipalign python3 zstd bc xmlstarlet

# 下载底包
download_rom "${baserom}" "${baseromUrl}"
# 下载移植包
download_rom "${portrom}" "${portromUrl}"

# 提取底包中所有镜像
extract_rom ${baserom} baserom/images/
# 提取底包中所有镜像
extract_rom ${portrom} portrom/

#判断是否是移植rom 根据移植包有没有下载成功和解压成功
if [ -f portrom/system.img ];then
    is_yz=true
else
    is_yz=false
fi

# 
if [ -f ./zhlhlf0.sh ];then
    green "存在自定义编辑 开始执行"
    . ./zhlhlf0.sh
else
    yellow "自定义编辑脚本不存在"
fi

if [ ! -f baserom/images/boot.img ];then
    z=0
    find_list="boot*offi*.img boot*ksu*.img"
    for i in $find_list;do
        boot_file=`find baserom/images -name $i | awk 'NR==1'`
        if [ "$boot_file" ];then
            z=1
            yellow "没在底包中不存在boot.img 但是存在 $boot_file"
            mv -f $boot_file baserom/images/boot.img
            break
        fi
    done
    if [ $z = 0 ];then
        yellow "底包中不存在boot.img"
        exit 1
    fi
fi

if [ $is_yz = true ];then
    #分解底包指定文件
    green "开始分解底包中指定镜像"
    list="system product system_ext my_product my_manifest odm"
    for image in $list;do
        if [ -f baserom/images/${image}.img ];then
            extract_img baserom/images/${image}.img baserom/images
        fi
    done

    # Move those to portrom folder. We need to pack those imgs into final port rom
    green "开始分解要替换为底包于目标包的镜像" 
    list="vendor odm my_company my_preload boot"
    for image in $list;do
        if [ -f baserom/images/${image}.img ];then
            extract_img baserom/images/${image}.img portrom/images
        else
            yellow "$image 不存在"
        fi
    done

    # 提取目标rom指定镜像并分解
    green "开始分解目标包剩余逻辑分区镜像" 
    list=${super_list}
    list+=" reserve"
    for image in ${list};do
        rm -rf baserom/images/${image}.img
        if [ -d portrom/images/${image} ];then
            continue
        fi
        if [ -f portrom/${image}.img ];then
            extract_img portrom/${image}.img portrom/images
            rm -rf portrom/${image}.img
        fi
    done

    get_rom_msg baserom/images portrom/images

    #全局替换device_code
    change_device_buildProp portrom/images
    
    # fix patchs
    # . ./patch.sh
else
    list=${super_list}
    list+=" boot reserve"
    for image in $list;do
        if [ -f baserom/images/${image}.img ];then
            extract_img baserom/images/${image}.img portrom/images
            rm -rf baserom/images/${image}.img
        fi
    done

    get_rom_msg portrom/images

fi

if grep -q "ro.build.ab_update=true" portrom/images/vendor/build.prop; then
    update_type=AB
else
    update_type=A
fi

# 通常是精简脚本 在打解目录执行
if [ -f ./zhlhlf1.sh ];then
    green "存在自定义编辑 开始执行"
    cd portrom/images
    . ../../zhlhlf1.sh
    cd ../../
else
    yellow "自定义编辑脚本不存在"
fi

# build.prop 修改 时间
change_buildTime_buildProp portrom/images

blue "去系统apk签名验证.."
#处理 framework.jar 去系统apk签名验证
patch_methods="getMinimumSignatureSchemeVersionForTargetSdk "
paths="android/util/apk "
patch1_jar portrom/images/system/system/framework/framework.jar "$paths" "$patch_methods"

#处理 services.jar 去系统apk签名验证
patch_methods="--assertMinSignatureSchemeIsValid "
paths="com/android/server/pm/ "
patch1_jar portrom/images/system/system/framework/services.jar "$paths" "$patch_methods"

#处理 services.jar 去系统apk签名验证
patch_methods="getMinimumSignatureSchemeVersionForTargetSdk"
paths="com/android/server/pm/ "
patch2_jar portrom/images/system/system/framework/services.jar "$paths" "$patch_methods"

#添加erofs文件系统fstab
if [ $pack_type = "erofs" ];then
    edit_fstab_ext_to_erofs portrom/images
fi

if [ $disable_avb_verify = true ];then
    disable_avb_verify portrom/images
fi

if [ $remove_data_encrypt = true ];then
    remove_data_encrypt portrom/images
fi

if [ "$base_rom_density" ];then
    edit_rom_density portrom/images $base_rom_density
fi

# 打包boot镜像
repack_img "portrom/images/boot"

# 打包各镜像img
for pname in ${super_list};do
    if [ -d "portrom/images/$pname" ];then
        repack_img "portrom/images/$pname" $pack_type
    fi
done

# 
cd portrom/images
rm -r $(ls --hide out)
mv out/*.img ./
mv boot.img ../../out/images 
cd ../../

# 打包super
if [ $make_super = true ];then

    data=`grep "$base_product_device $update_type" bin/superMsgList.txt`
    super_size=`echo $data | cut -d ' ' -f 3`
    super_type=`echo $data | cut -d ' ' -f 4`

    list=""
    for pa in ${super_list};do
        if [ -f "portrom/images/${pa}.img" ];then
            list+="$pa "
        fi
    done
    make_super "$super_size" "portrom/images" "$list" "$super_type" "$super_slot"

    blue "正在压缩 super.img"
    zstd portrom/images/super.img -o out/images/super.zst
else
    mv portrom/images/*.img out/images
fi

blue "正在生成刷机zip"

for i in dtbo *vbmeta*
do
	mv -f baserom/images/$i.img out/images/
done

mv baserom/images/*.* out/firmware-update
rm -rf portrom out/firmware-update/recovery.img 

green "edit vbmeta.img 关闭avb校验"
patch-vbmeta.py out/images/vbmeta.img

cd out
# 在打包zip之前执行
if [ -f ../zhlhlf2.sh ];then
    green "存在自定义编辑 开始执行"
    . ../zhlhlf2.sh
else
    yellow "自定义编辑脚本不存在"
fi

green "要打包为zip的文件目录树"
green "---------------------"
du -h `find -type f`
green "---------------------"
zip -qr out.zip *
time=$(date +"%Y-%m-%d")
hash=$(md5sum out.zip | head -c 10)

if [ $is_yz = true ];then
    mv out.zip ${base_product_device}_${update_type}_${os_type}_${port_android_version}_from_${port_product_device}_fw_${base_rom_version}-${pack_type}_${time}.zip
else
    mv out.zip ${base_product_device}_${update_type}_${os_type}_${base_rom_version}-${pack_type}_${time}.zip
fi

cd ..
green "输出包路径："
green `ls out/*.zip`
