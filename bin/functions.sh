#!/bin/bash

work_dir=$(pwd)

# Define color output function
error() {
    if [ "$#" -eq 2 ]; then
        
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$1"\033[0m"
    else
        echo "Usage: error <Chinese> <English>"
    fi
}

yellow() {
    if [ "$#" -eq 2 ]; then
        
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$1"\033[0m"
    else
        echo "Usage: yellow <Chinese> <English>"
    fi
}

blue() {
    if [ "$#" -eq 2 ]; then
        
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$1"\033[0m"
    else
        echo "Usage: blue <Chinese> <English>"
    fi
}

green() {
    if [ "$#" -eq 2 ]; then
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$1"\033[0m"
    else
        echo "Usage: green <Chinese> <English>"
    fi
}

#Check for the existence of the requirements command, proceed if it exists, or abort otherwise.
exists() {
    command -v "$1" > /dev/null 2>&1
}

abort() {
    error "--> Missing $1 abort! please run ./setup.sh first (sudo is required on Linux system)"
    error "--> 命令 $1 缺失!请重新运行setup.sh (Linux系统sudo ./setup.sh)"
    exit 1
}

check() {
    for b in "$@"; do
        exists "$b" || abort "$b"
    done
}

# $1 boot文件路径
# $2 解包后的boot文件夹存放位置
unpack_boot() {
    pwd=$(pwd)
    input_file=$1
    out_file=$2
    file_name=`basename $input_file`
    line=$(echo $file_name | cut -d '.' -f 1)
    
    rm -rf $out_file/$line
    mkdir -p $out_file/$line
    if [ ! -d "$out_file/config" ];then
        mkdir $out_file/config
    fi
    
    cp -r $input_file $out_file/$line
    cd $out_file/$line

    magiskboot unpack -h $file_name > /dev/null 2>&1
    if [ "$?" = "1" ]; then
        error "> 分解 $file_name 失败!"
        cd ../
        rm -rf $line
    else
    	echo "boot" > ../config/${line}_info
        if [ -f ramdisk.cpio ]; then   
            #comp=$(magiskboot decompress ramdisk.cpio | grep -v 'raw' | sed -n 's;.*\[\(.*\)\];\1;p')
            echo "$comp" >> ../config/${line}_info
            if [ "$comp" ]; then                
                mv -f ramdisk.cpio ramdisk.cpio.$comp
                magiskboot decompress ramdisk.cpio.$comp ramdisk.cpio > /dev/null 2>&1
                if [ $? != 0 ] && $comp --help; then
                    $comp -dc ramdisk.cpio.$comp > ramdisk.cpio
                fi
            fi
            mkdir -p ramdisk
            chmod 755 ramdisk
            cd ramdisk
            EXTRACT_UNSAFE_SYMLINKS=1 cpio -d -F ../ramdisk.cpio -i  > /dev/null 2>&1
            if [ "$?" = "1" ]; then
                error "> 分解 $file_name 中 ramdisk.cpio 失败!"
                cd ../../
                rm -rf $line
                rm -rf config/${line}_*                
            fi
        fi
    fi
    cd $pwd        
}

# $1 boot 解包后的文件夹
# 将打包至 $1/../out目录下
repack_boot(){
    pwd=$(pwd)
    input_files=$1
    line=`basename $input_files`
    
    cd $input_files
    comp=`sed -n 2p ../config/${line}_info`
    
    if [ "$comp" ]; then
      magiskboot compress=$comp ramdisk_new.cpio
      if [ $? != 0 ] && $comp --help > /dev/null 2>&1; then
          $comp -9c ramdisk_new.cpio >ramdisk.cpio.$comp
      fi
    else
      cd ramdisk && find | sed 1d | cpio -H newc -R 0:0 -o -F ../ramdisk-new.cpio > /dev/null 2>&1;
      cd ..
    fi
    ramdisk=$(ls ramdisk-new* | tail -n1)
    if [ "$ramdisk" ]; then
      mv -f $ramdisk ramdisk.cpio
      case $comp in
      cpio) nocompflag="-n" ;;
      esac
      magiskboot repack $nocompflag $line.img new-$line.img > /dev/null 2>&1;
      rm -r ramdisk.cpio
    fi

    if [ ! -d ../out/ ];then
    	mkdir ../out
    fi
    mv -f new-$line.img ../out/$line.img
    cd $pwd        
}

make_super(){
    yellow "start pack super.img..."
    super_size=$1 
    super_dir="$2"
    super_list="$3" #system ...
    super_type=$4  #VAB or AB
    super_slot=$5  #a or b
    
    sSize=0
    super_group=qti_dynamic_partitions
    argvs="--metadata-size 65536 --super-name super "
    for i in $super_list; do
        image=$(echo "$i" | sed 's/.img//g')
        img_size=$(du -sb $super_dir/$image.img | tr -cd 0-9)
        if [ "$super_type" = "VAB" ] || [ "$super_type" = "AB" ];then
            if [ "$super_slot" = "a" ];then    
          	  argvs+="--partition "$image"_a:none:$img_size:${super_group}_a --image "$image"_a=$super_dir/$image.img --partition "$image"_b:none:0:${super_group}_b "
            elif [ "$super_slot" = "b" ];then    
          	  argvs+="--partition "$image"_b:none:$img_size:${super_group}_b --image "$image"_b=$super_dir/$image.img --partition "$image"_a:none:0:${super_group}_a "
            fi
        else
            argvs+="--partition "$image":none:$img_size:${super_group} --image "$image"=$super_dir/$image.img "
        fi
        sSize=$((sSize + img_size))
        blue "Super sub-partition [$image] size: [$img_size]"
    done

    argvs+="--device super:$super_size "
    if [ "$super_type" = "VAB" ] || [ "$super_type" = "AB" ];then
        argvs+="--metadata-slots 3 --virtual-ab "
        argvs+="--group ${super_group}_a:$super_size "
        argvs+="--group ${super_group}_b:$super_size "
    else
        argvs+="--metadata-slots 2 "
        argvs+="--group ${super_group}:$super_size "
    fi
    
    if [ -f "$super_dir/super.img" ];then
        rm -rf $super_dir/super.img
    fi
    yellow "super_type: $super_type  slot: $super_slot  set-size: ${super_size} allSize: $sSize"
    argvs+="-F --output $super_dir/super.img"
    if [ ! -d tmp ];then
    	mkdir tmp
    fi
    lpmake $argvs > tmp/make_super.txt 2>&1
    if [ -f "$super_dir/super.img" ];then
        green "successfully repack super.img"
    else
        cat tmp/make_super.txt
        error "fail pack super.img"
        exit 1
    fi
}

download_rom(){
    if [ ! -f "$1" ] && [ "$(echo $2 | grep http)" != "" ];then
        blue "正在下载 $1"
        aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 "$2" -o $1
        if [ ! -f "$1" ];then
            error "下载错误"
        fi
    elif [ -f "$1" ];then
        green "已存在包: $1" 
    else
        yellow "本地尚未存在 并且传入参数并不是下载链接 终止"
    fi
}

# $1 包的当前绝对路径
# $2 提取的镜像存放位置
# 会删除$1文件
extract_rom(){
    if [ ! -f $1 ];then
        yellow "$1 不存在"
        return
    fi
    rm -rf tmp/extractRom
    mkdir -p tmp/extractRom

    rom_pack_type=`gettype.py $1`
    if [ $rom_pack_type = zip ];then
        blue "[zip] 解压 $1 ..."
        unzip -qo $1 -d tmp/extractRom || error "[zip]解压 $1 时出错"       
    elif [ $rom_pack_type = 7z ];then
        blue "[7z] 解压 $1 ..."
        7z x $1 -otmp/extractRom >/dev/null 2>&1 || error "[7z]解压 $1 时出错"    
    else
        error "此包暂不支持"
        exit 1
    fi

    #进一步解压存在的zip
    file=`find tmp/extractRom -name "*.zip"`
    if [ "$file" ];then
        for i in $file;do
            blue "[zip] 解压 $i ..."
            unzip -qo $i -d tmp/extractRom
            rm -r $i
        done
    fi

    #存在payload.bin即分解
    file=`find tmp/extractRom -name "payload.bin"`
    if [ "$file" ];then
        blue "开始分解 payload.bin包"
        payload-dumper-go -o tmp/extractRom tmp/extractRom/payload.bin >/dev/null 2>&1 ||error "分解 [payload.bin] 时出错"
        rm -r tmp/extractRom/payload.bin
    fi

    #存在br文件即分解
    file=`find tmp/extractRom -name "*new.dat.br"`
    if [ "$file" ];then
        cd tmp/extractRom
        for i in $(ls *.new.dat.br)
        do
            blue "[br]分解 $i ..."
            line=$(basename $i .new.dat.br) 
            brotli -d $i
            rm -r $i
            if [ -f ${line}.transfer.list ];then
                a=${line}.transfer.list
                b=${line}.new.dat
                c="${line/.*/}.img"
                sdat2img.py $a $b $c > /dev/null 2>&1
                rm -r ${line}.transfer.list
                rm -r ${line}.new.dat
            fi
        done
        rm -r *.dat
        cd ../../
    fi

    #分解super.zst
    file=`find tmp/extractRom -name "*super*"`
    if [ "$file" ] && [ `gettype.py $file` = zst ];then
            blue "[zst]解压 $file ..."
            zstd --rm -d $file -o tmp/extractRom/super.img >> /dev/null 2>&1
    fi

    #分解super.img
    file=`find tmp/extractRom -name "super.*"`
    if [ "$file" ] && [ `gettype.py $file` = super ];then
        blue "[super]解压 $file ..."
        rm -rf tmp/extractRom/super
        mkdir tmp/extractRom/super
        lpunpack.py $file tmp/extractRom/super >> /dev/null 2>&1 || ( error "[super] 分解失败" ; exit 1 )
        rm -r $file
        for i in $(ls tmp/extractRom/super/*);do
        	dataSize=`du $i | cut -f 1`
            if [ $dataSize = 0 ];then
                rm -r $i
                continue
            fi
            new_file=`echo $i | sed s/_[ab].img/.img/g`
            mv -n "$i" "$new_file"
        done
    fi

    find tmp/extractRom -name "*.img" > rom_image_list
    i=1
    while true
    do
        tt=`sed -n ${i}p rom_image_list`
        i=$((i+1))
        if [ ! "$tt" ];then
            break
        fi
        mv -n "$tt" "$2"
    done

    rm -rf tmp/extractRom rom_image_list 
    green "分解完成 -> $2"
}


# $1 jar文件位置
# $2 查找目录
# $3 patch的方法
patch1_jar(){
    if [ ! "$1" ];then return ; fi
    name=`basename $1 | awk -F'.' '{print $1}'`
    rm -rf tmp/$name/
    mkdir -p tmp/$name/
    cp -rf $1 tmp/$name.jar
    java -jar bin/apktool/APKEditor.jar d -f -i tmp/$name.jar -o tmp/$name > /dev/null 2>&1 || (error "解包tmp/$name.jar失败" ; return)

    paths=""
    for i in $2
    do
        hh="tmp/$name/smali/*/$i"
        paths+="$hh "
    done

    #Coloros 系统的该方法位置
    files=$(find $paths -type f -name "*.smali")

    for file in $files; do
        patchmethod.py $file $3
    done

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/$name -o tmp/${name}_patched.jar > /dev/null 2>&1 || (error "打包tmp/$name.jar失败" ; return)
    cp -rf tmp/${name}_patched.jar $1
    rm -r tmp
}

# $1 jar文件位置
# $2 查找目录
# $3 patch的方法
# patch1_jar(){

#     if [ $is_eu_rom == "true" ]; then
#        SMALI_COMMAND="java -jar bin/apktool/smali-3.0.5.jar"
#        BAKSMALI_COMMAND="java -jar bin/apktool/baksmali-3.0.5.jar" 
#     else
#        SMALI_COMMAND="java -jar bin/apktool/smali.jar"
#        BAKSMALI_COMMAND="java -jar bin/apktool/baksmali.jar"
#     fi

#     infile=$1
#     if [ -f $infile ];then
#         filename=$(basename $infile)
#         name=${filename%.*}
#         rm -rf tmp
#         mkdir -p tmp/$name/
#         cp -rf $infile tmp
#         7z x -y tmp/$filename *.dex -otmp/$name >/dev/null
#         for dexfile in tmp/$name/*.dex;do
#             smalifname=${dexfile%.*}
#             smalifname=$(echo $smalifname | cut -d "/" -f 3)
#             ${BAKSMALI_COMMAND} d --api ${port_android_sdk} ${dexfile} -o tmp/$name/$smalifname 2>&1 || (error " Baksmaling 失败" ; return)
#             rm -r $dexfile
#         done

#         paths=""
#         for i in $2
#         do
#             hh="tmp/$name/*/$i"
#             paths+="$hh "
#         done

#         #Coloros 系统的该方法位置
#         files=$(find $paths -type f -name "*.smali")

#         for file in $files; do
#             patchmethod.py $file $3
#         done


#         for smalidir in $(ls tmp/$name);do
#             ${SMALI_COMMAND} a --api ${port_android_sdk} tmp/$name/${smalidir} -o tmp/${smalidir}.dex 2>&1 || (error " Baksmaling 失败" ; return)
#         done
#         cd tmp
#         7z a -y -mx0 -tzip $filename *.dex  > /dev/null 2>&1 || (error "修改$filename失败" ; return)
#         cd ../
#         mv -f tmp/$filename $infile
#         rm -r tmp
#     fi

# }

# $1 jar文件位置
# $2 查找目录
# $3 patch的方法的调用
# 把调用返回置为0
patch2_jar(){
    if [ ! "$1" ];then return ; fi
    name=`basename $1 | awk -F'.' '{print $1}'`
    rm -rf tmp/$name/
    mkdir -p tmp/$name/
    cp -rf $1 tmp/$name.jar
    java -jar bin/apktool/APKEditor.jar d -f -i tmp/$name.jar -o tmp/$name  > /dev/null 2>&1

    paths=""
    for i in $2
    do
        hh="tmp/$name/smali/*/$i"
        paths+="$hh "
    done

    files=$(find $paths -type f -name "*.smali")
    for i in $files; do
        x=`grep -n "$3" "$i" | cut -d ':' -f 1`
        if [ "$x" ];then
            yellow "$i patched"
            x1=$((x+2))
            reg=`sed -n ${x1}p $i | cut -d 't' -f 2`
            sed -i "${x1}i\\\tconst/4 $reg, 0x0" $i
            sed -i "${x}d" $i
            sed -i "${x1}d" $i
        fi
    done

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/$name -o tmp/${name}_patched.jar > /dev/null 2>&1
    cp -rf tmp/${name}_patched.jar $1
    rm -r tmp
}


# $1 jar文件位置
# $2 查找目录
# $3 patch的方法的调用
# 把调用返回置为0
# patch2_jar(){
#     port_android_sdk=34
#     if [ $is_eu_rom == "true" ]; then
#        SMALI_COMMAND="java -jar bin/apktool/smali-3.0.5.jar"
#        BAKSMALI_COMMAND="java -jar bin/apktool/baksmali-3.0.5.jar" 
#     else
#        SMALI_COMMAND="java -jar bin/apktool/smali.jar"
#        BAKSMALI_COMMAND="java -jar bin/apktool/baksmali.jar"
#     fi

#     infile=$1
#     if [ -f $infile ];then
#         filename=$(basename $infile)
#         name=${filename%.*}
#         rm -rf tmp
#         mkdir -p tmp/$name/
#         cp -rf $infile tmp
#         7z x -y tmp/$filename *.dex -otmp/$name >/dev/null
#         for dexfile in tmp/$name/*.dex;do
#             smalifname=${dexfile%.*}
#             smalifname=$(echo $smalifname | cut -d "/" -f 3)
#             ${BAKSMALI_COMMAND} d --api ${port_android_sdk} ${dexfile} -o tmp/$name/$smalifname 2>&1 || error " Baksmaling 失败"
#             rm -r $dexfile
#         done

#         paths=""
#         for i in $2
#         do
#             hh="tmp/$name/*/$i"
#             paths+="$hh "
#         done

#         files=$(find $paths -type f -name "*.smali")
#         for i in $files; do
#             x=`grep -n "$3" "$i" | cut -d ':' -f 1`
#             if [ "$x" ];then
#                 yellow "$i patched"
#                 x1=$((x+2))
#                 reg=`sed -n ${x1}p $i | cut -d 't' -f 2`
#                 sed -i "${x1}i\\\tconst/4 $reg, 0x0" $i
#                 sed -i "${x}d" $i
#                 sed -i "${x1}d" $i
#             fi
#         done

#         for smalidir in $(ls tmp/$name);do
#             ${SMALI_COMMAND} a --api ${port_android_sdk} tmp/$name/${smalidir} -o tmp/${smalidir}.dex 2>&1 || (error " Baksmaling 失败" ; return)
#         done
#         cd tmp
#         7z a -y -mx0 -tzip $filename *.dex  > /dev/null 2>&1 || (error "修改$filename失败" ; return)
#         cd ../
#         mv -f tmp/$filename $infile
#         rm -r tmp
#     fi
# }

# Replace Smali code in an APK or JAR file, without supporting resource patches.
# $1: apk文件位置  例如portrom/images/system/system.apk
# $2: Target Smali file (supports relative paths for Smali files)
# $3: Value to be replaced
# $4: Replacement value
patch_smali(){
    if [ ! "$1" ];then return ; fi
    name=`basename $1 | awk -F'.' '{print $1}'`
    rm -rf tmp/$name/
    mkdir -p tmp/$name/
    cp -rf $1 tmp/$name.apk
    java -jar bin/apktool/APKEditor.jar d -f -i tmp/$name.apk -o tmp/$name  > /dev/null 2>&1

    paths=""
    for i in $2
    do
        hh="tmp/$name/smali/*/$i"
        paths+="$hh "
    done

    files=$(find $paths -type f -name "*.smali")
    for targetsmali in $files; do
        if [ ! "`cat $targetsmali | grep $3`" ];then
            continue
        fi
        yellow "patch ${targetsmali} ..."
        sed -i "s/$3/$4/g" $targetsmali
    done

    java -jar bin/apktool/APKEditor.jar b -f -i tmp/$name -o tmp/${name}_patched.apk > /dev/null 2>&1
    zipalign -p -f -v 4 tmp/${name}_patched.apk tmp/${name}_sign.apk > /dev/null 2>&1 || (error "zipalign错误，请检查原因。" ; return)
    cp -rf tmp/${name}_sign.apk $1
    rm -r tmp
}

# Replace Smali code in an APK or JAR file, without supporting resource patches.
# $1: apk文件位置  例如portrom/images/system/system.apk
# $2: Target Smali file (supports relative paths for Smali files)
# $3: Value to be replaced
# $4: Replacement value
# patch_smali() {
#     if [[ $is_eu_rom == "true" ]]; then
#        SMALI_COMMAND="java -jar bin/apktool/smali-3.0.5.jar"
#        BAKSMALI_COMMAND="java -jar bin/apktool/baksmali-3.0.5.jar" 
#     else
#        SMALI_COMMAND="java -jar bin/apktool/smali.jar"
#        BAKSMALI_COMMAND="java -jar bin/apktool/baksmali.jar"
#     fi
#     infile=$1
#     if [ -f $infile ];then
#         filename=$(basename $infile)
#         yellow "正在修改 $filename" "Modifying $filename"
#         name=${filename%.*}
#         rm -rf tmp/$name/
#         mkdir -p tmp/$name/
#         cp -rf $infile tmp/$name/
#         7z x -y tmp/$name/$filename *.dex -otmp/$name >/dev/null
#         for dexfile in tmp/$name/*.dex;do
#             smalifname=${dexfile%.*}
#             smalifname=$(echo $smalifname | cut -d "/" -f 3)
#             ${BAKSMALI_COMMAND} d --api ${port_android_sdk} ${dexfile} -o tmp/$name/$smalifname 2>&1 || (error " Baksmaling 失败" ; return)
#             ${SMALI_COMMAND} a --api ${port_android_sdk} tmp/$name/${smalidir} -o tmp/$name/${smalidir}.dex > /dev/null 2>&1 || (error " Baksmaling 失败" ; return) 
          
#         done

#         search_paths=""
#         for i in $2
#         do
#             hh="tmp/$name/*/$i"
#             search_paths+="$hh "
#         done

#         targetsmalis=$(find $search_paths -type f)
#         for targetsmali in $targetsmalis
#         do
#             if [ ! "cat $targetsmali | grep ${search_pattern}" ];then
#                 continue
#             fi
#             smalidir=$(echo $targetsmali |cut -d "/" -f 3)
#             yellow "patch ${targetsmali} ..."
#             search_pattern=$3
#             repalcement_pattern=$4
#             if [[ $5 == 'regex' ]];then
#                  sed -i "/${search_pattern}/c\\${repalcement_pattern}" $targetsmali
#             else
#                 sed -i "s/$search_pattern/$repalcement_pattern/g" $targetsmali
#             fi
#             ${SMALI_COMMAND} a --api ${port_android_sdk} tmp/$name/${smalidir} -o tmp/$name/${smalidir}.dex > /dev/null 2>&1 || (error " Baksmaling 失败" ; return)
#             pushd tmp/$name/ >/dev/null || exit
#             7z a -y -mx0 -tzip $filename ${smalidir}.dex  > /dev/null 2>&1 || (error "修改$filename失败" ; return)
#             popd >/dev/null || exit
#         done

#         yellow "修补$filename 完成"
#         if [[ $filename == *.apk ]]; then
#             yellow "检测到apk，进行zipalign处理。。"
#             rm -rf ${infile}

#             # Align moddified APKs, to avoid error "Targeting R+ (version 30 and above) requires the resources.arsc of installed APKs to be stored uncompressed and aligned on a 4-byte boundary" 
#             zipalign -p -f -v 4 tmp/$name/$filename ${infile} > /dev/null 2>&1 || error "zipalign错误，请检查原因。"
#             yellow "apk zipalign处理完成"
#             yellow "复制APK到目标位置：${infile}"
#         else
#             yellow "复制修改文件到目标位置：${infile}"
#             cp -rf tmp/$name/$filename ${infile}
#         fi
#     else
#         error "Failed to find $1,please check it manually".
#     fi
# }

# $1 镜像输入
# $2 解包至
extract_img() {
    part_img=$1
    part_name=$(basename ${part_img})
    
    name=`echo $part_name | awk -F'.' '{print $1}'`
    target_dir=$2

    if [ -f ${part_img} ];then
    	rm -rf target_dir/$name
    	type=$(gettype.py ${part_img})

        if [ $type = sparse ];then
            blue "[$type] ${part_img} unsparse format..." 
            new_file=`dirname $part_img`/${name}_raw.img
            simg2img ${part_img} $new_file
            rm -r $part_img 
            mv $new_file $part_img
            extract_img $part_img $target_dir
            return
        fi

        if [ ! $type = unknow ];then
            blue "[$type] ${part_img} -> ${target_dir}/$name"
        else
            error "暂不支持分解 ${part_img}"
        fi

        if [ $type = "ext" ];then
            imgextractor.py ${part_img} ${target_dir} > /dev/null 2>&1  || { error "分解 ${part_name} 失败" "Extracting ${part_name} failed."; exit 1; }
        elif [ $type = "erofs" ];then
            extract.erofs -x -i ${part_img} -o $target_dir > /dev/null 2>&1 || { error "分解 ${part_name} 失败" "Extracting ${part_name} failed." ; exit 1; }
        elif [ $type = "boot" ] || [ $type = "vendor_boot" ];then
            type=boot
            unpack_boot "$part_img" "$target_dir"
        else
            error "无法识别img文件类型，请检查" "Unable to handle img, exit."
            exit 1
        fi

        if [ -d $target_dir/$name ];then
            green "[$type] ${part_img} extracted."
        fi
        if [ ! -d "$target_dir/config" ];then
        	mkdir $target_dir/config
    	fi
    	if [ ! $type = boot ];then #因为分解boot的函数已经执行过了 由于特殊性不能统一在此
            echo $type > $target_dir/config/${name}_info
        fi
    else
        yellow "$part_img 不存在"
    fi    
}

# $1 镜像 解包后的文件夹
# $2 erofs/ext 指定打包类型 没有则是解包时类型
# 将打包至 $1/../out目录下
repack_img(){
    input_file=$1
    name=`basename $input_file`
    img_out="$input_file/../out/$name.img"
    
    type=`sed -n 1p $input_file/../config/${name}_info`    
    fs=$input_file/../config/${name}_fs_config
    file=$input_file/../config/${name}_file_contexts

    # 判断$2 是否有输入 并...
    is=0
    is1=0
    if [ "$2" ] && [ $2 != auto ];then
    	for i in "ext" "erofs"  # 可以互相自定义转换的两个类型
    	do
    		if [ $type = $i ];then
         	   is=1
        	fi
    		if [ $2 = $i ];then
         	   is1=1
        	fi            
    	done
    	if [ $is = 1 ] && [ $is1 = 1 ];then
    	   type=$2
    	fi
    fi

    if [ ! -d $input_file/../out ];then
    	mkdir $input_file/../out
    fi
    
    blue "[$type] $input_file -> $name.img"

    if [ -f $fs -a -f $file ];then
    	fspatch.py $input_file $fs >/dev/null 2>&1 || (error "fspatch error" ; exit 1)
    	contextpatch.py $input_file $file >/dev/null 2>&1 || (error "contextpatch error" ; exit 1)
    fi

    if [ -f $input_file/$name/build.prop ];then
        mount_dir="/"
    else
        mount_dir="/$name"
    fi
    UTC=$(date -u +%s)

    if [ $type = "erofs" ];then
        mkfs.erofs -zlz4hc,1 -T $UTC --mount-point=/$name --fs-config-file=$fs --file-contexts=$file $img_out $input_file >/dev/null 2>&1 || rm -rf $img_out
    elif [ $type = "ext" ];then
        if [[ "$OSTYPE" == "darwin"* ]];then
            size_now=$(find $input_file | xargs stat -f%z | awk ' {s+=$1} END { print s }' )
        else
            size_now=$(du -sb $input_file |tr -cd 0-9)
        fi

        size="$(($size_now / 4096))"    
        xx=0
        while true;do
            if [ $xx = "20" ];then
                break
            fi
                mke2fs -O ^has_journal -L $input_file -I 256 -i 102400 -M $mount_dir -m 0 -t ext4 -b 4096 $img_out $size >/dev/null 2>&1
                e2fsdroid -e -T $UTC -C $fs -S $file -f $input_file -a /$name $img_out >/dev/null 2>&1 || rm -rf $img_out
            if [ ! -f $img_out ];then
                size=$(($size + 1024))
                xx=$(($xx + 1)) 
            else
                break
            fi
        done
    elif [ $type = "boot" ];then
    	repack_boot "$input_file"
    fi
    if [ -f "$img_out" ];then
        green "[$type] repack ${name}.img successfully"
    else
        error "[$type] repack ${name}.img fail"
        exit 1
    fi
}

# $1 镜像解包后的位置 比如 asd/boot 那应传入 asd  
disable_avb_verify() {
    blue "移除avb验证"
    for i in "vendor/etc/fstab.qcom" "boot/ramdisk/fstab.qcom" "boot/ramdisk/oplus.fstab" "boot/ramdisk/system/etc/fstab.qcom" 
    do
        file=`echo $1 | sed 's/\/$//'`/$i
        if [ ! -f $file ];then
            continue
        fi
        green "edit $file ..."
        sed -i s#avb.*system,#""#g $file
        sed -i s#avb.*vendor,#""#g $file
        sed -i 's/,avb_keys.*key//g' $file
    done
}

# $1 镜像解包后的位置 比如 asd/boot 那应传入 asd  
remove_data_encrypt() {
    blue "移除data分区加密"
    for i in "vendor/etc/fstab.qcom" "boot/ramdisk/fstab.qcom" "boot/ramdisk/oplus.fstab" "boot/ramdisk/system/etc/fstab.qcom" 
    do
        file=`echo $1 | sed 's/\/$//'`/$i
        if [ ! -f $file ];then
            continue
        fi
        green "edit $file ..."
        sed -i s/fileencryption.*quota/quota/g "$file"
    done
}

# $1 镜像解包后的位置 比如 asd/boot 那应传入 asd  
edit_fstab_ext_to_erofs(){
    blue "编辑fstab挂载点ext4 为erofs"
    for i in "vendor/etc/fstab.qcom" "boot/ramdisk/fstab.qcom" "boot/ramdisk/oplus.fstab" "boot/ramdisk/system/etc/fstab.qcom" 
    do
        file=`echo $1 | sed 's/\/$//'`/$i
        if [ ! -f $file ];then
            continue
        fi
        green "edit $file ..."
            sed -i 's/ext4.*ro,barrier=1.*wait,/erofs      ro            wait,/g' $file
    done    
}

edit_rom_density(){
    blue "设置ro.sf.lcd_density为: $2"
    for prop in $(find $1 -type f -name "build.prop");do
        if grep -q "ro.sf.lcd_density" ${prop};then
            sed -i "s/ro.sf.lcd_density=.*/ro.sf.lcd_density=$2/g" ${prop}
        fi
    done
}

change_buildTime_buildProp(){
    # build.prop 修改
    blue "正在修改 build.prop 中 build.date属性..."

    buildDate=$(date -u +"%a %b %d %H:%M:%S UTC %Y")
    buildUtc=$(date +%s)
    
    for i in $(find $1 -type f -name "build.prop");do
        sed -i "s/ro.build.date=.*/ro.build.date=${buildDate}/g" ${i}
        sed -i "s/ro.build.date.utc=.*/ro.build.date.utc=${buildUtc}/g" ${i}
        sed -i "s/ro.odm.build.date=.*/ro.odm.build.date=${buildDate}/g" ${i}
        sed -i "s/ro.odm.build.date.utc=.*/ro.odm.build.date.utc=${buildUtc}/g" ${i}
        sed -i "s/ro.vendor.build.date=.*/ro.vendor.build.date=${buildDate}/g" ${i}
        sed -i "s/ro.vendor.build.date.utc=.*/ro.vendor.build.date.utc=${buildUtc}/g" ${i}
        sed -i "s/ro.system.build.date=.*/ro.system.build.date=${buildDate}/g" ${i}
        sed -i "s/ro.system.build.date.utc=.*/ro.system.build.date.utc=${buildUtc}/g" ${i}
        sed -i "s/ro.product.build.date=.*/ro.product.build.date=${buildDate}/g" ${i}
        sed -i "s/ro.product.build.date.utc=.*/ro.product.build.date.utc=${buildUtc}/g" ${i}
        sed -i "s/ro.system_ext.build.date=.*/ro.system_ext.build.date=${buildDate}/g" ${i}
        sed -i "s/ro.system_ext.build.date.utc=.*/ro.system_ext.build.date.utc=${buildUtc}/g" ${i}
        sed -i "s/persist.sys.timezone=.*/persist.sys.timezone=Asia\/Shanghai/g" ${i}
        # 添加build user信息
        sed -i "s/ro.build.user=.*/ro.build.user=${build_user}/g" ${i}
    done

}

get_rom_msg(){

    blue "Fetching ROM build prop."

    base_android_version=$(< $1/my_product/build.prop grep "ro.build.version.oplusrom" |awk 'NR==1' |cut -d '=' -f 2)
    base_android_sdk=$(< $1/system/system/build.prop grep "ro.system.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
    base_rom_version=$(<  $1/my_manifest/build.prop grep "ro.build.display.ota" | awk 'NR==1' | cut -d '=' -f 2 | cut -d '_' -f 2-)
    base_device_code=$(< $1/my_manifest/build.prop grep "ro.oplus.version.my_manifest" | awk 'NR==1' | cut -d '=' -f 2 | cut -d "_" -f 1)
    base_product_device=$(< $1/my_manifest/build.prop grep "ro.product.device" |awk 'NR==1' |cut -d '=' -f 2)
    base_product_name=$(< $1/my_manifest/build.prop grep "ro.product.name" |awk 'NR==1' |cut -d '=' -f 2)
    base_market_name=$(< $1/odm/build.prop grep "ro.vendor.oplus.market.name" |awk 'NR==1' |cut -d '=' -f 2)
    base_rom_model=$(< $1/my_manifest/build.prop grep "ro.product.model" |awk 'NR==1' |cut -d '=' -f 2)
    base_my_product_type=$(< $1/my_product/build.prop grep "ro.oplus.image.my_product.type" |awk 'NR==1' |cut -d '=' -f 2)

    if [ ! "$2" ];then
        port_android_sdk=$base_android_sdk
        
        green "Android Version: BASEROM:[Android ${base_android_version}]"
        green "SDK Verson: BASEROM: [SDK ${base_android_sdk}]"
        green "ROM Version: BASEROM: [${base_rom_version}]"
        green "Device Code: BASEROM: [${base_device_code}]"
        green "Product Device: BASEROM: [${base_product_device}]"
        green "Product Name: BASEROM: [${base_product_name}]"
        green "Market Name: BASEROM: [${base_market_name}]"
        green "Product Model: BASEROM: [${base_rom_model}]"
        return
    fi

    port_android_version=$(< $2/my_product/build.prop grep "ro.build.version.oplusrom" |awk 'NR==1' |cut -d '=' -f 2)
    port_android_sdk=$(< $2/system/system/build.prop grep "ro.system.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
    port_rom_version=$(<  $2/my_manifest/build.prop grep "ro.build.display.ota" | awk 'NR==1' | cut -d '=' -f 2 | cut -d '_' -f 2-)
    port_device_code=$(< $2/my_manifest/build.prop grep "ro.oplus.version.my_manifest" | awk 'NR==1' | cut -d '=' -f 2 | cut -d "_" -f 1)
    port_product_device=$(< $2/my_manifest/build.prop grep "ro.product.device" |awk 'NR==1' |cut -d '=' -f 2)
    port_product_name=$(< $2/my_manifest/build.prop grep "ro.product.name" |awk 'NR==1' |cut -d '=' -f 2)
    port_market_name=$(< $2/odm/build.prop grep "ro.vendor.oplus.market.name" |awk 'NR==1' |cut -d '=' -f 2)
    port_rom_model=$(< $2/my_manifest/build.prop grep "ro.product.model" |awk 'NR==1' |cut -d '=' -f 2)
    port_my_product_type=$(< $2/my_product/build.prop grep "ro.oplus.image.my_product.type" |awk 'NR==1' |cut -d '=' -f 2)
    
    target_display_id=$(< $2/my_manifest/build.prop grep "ro.build.display.id" |awk 'NR==1' |cut -d '=' -f 2 | sed 's/$port_device_code/$base_device_code/g')

    green "Android Version: BASEROM:[Android ${base_android_version}], PORTROM [Android ${port_android_version}]"
    green "SDK Verson: BASEROM: [SDK ${base_android_sdk}], PORTROM: [SDK ${port_android_sdk}]"
    green "ROM Version: BASEROM: [${base_rom_version}], PORTROM: [${port_rom_version}] "
    green "Device Code: BASEROM: [${base_device_code}], PORTROM: [${port_device_code}]"
    green "Product Device: BASEROM: [${base_product_device}], PORTROM: [${port_product_device}]"
    green "Product Name: BASEROM: [${base_product_name}], PORTROM: [${port_product_name}]"
    green "Market Name: BASEROM: [${base_market_name}], PORTROM: [${port_market_name}]"
    green "Product Model: BASEROM: [${base_rom_model}], PORTROM: [${port_rom_model}]"
}

#$1 全局路径
change_device_buildProp(){
    blue "全局替换device_code"
    for i in $(find $1 -type f -name "build.prop");do
        if [ "$port_device_code" -a "$base_device_code" ];then
            sed -i "s/$port_device_code/$base_device_code/g" ${i}
        fi

        if [ "$port_rom_model" -a "$base_rom_model" ];then
            sed -i "s/$port_rom_model/$base_rom_model/g" ${i}
        fi

        if [ "$port_product_name" -a "$base_product_name" ];then
            sed -i "s/$port_product_name/$base_product_name/g" ${i}
        fi

        if [ "$port_my_product_type" -a "$base_my_product_type" ];then        
            sed -i "s/$port_my_product_type/$base_my_product_type/g" ${i}
        fi

        if [ "$port_market_name" -a "$base_market_name" ];then
            sed -i "s/$port_market_name/$base_market_name/g" ${i}
        fi

        if [ "$port_product_device" -a "$base_product_device" ];then
            sed -i "s/$port_product_device/$base_product_device/g" ${i}
        fi
    done
}

#$1 第几行
#$2 key
#$3 文件
get_prop_line(){
    gg=`sed -n ${1}p $3 | sed "s/.*${2}=\"//g" | cut -d \" -f 1`
    echo $gg
}


#$1 第几行
#$2 key
#$3 文件
#$4 new_vlaue
replace_prop_line(){
    sed -i "${1}s/$2=\"[^\"]*\" /$2=\"$4\" /" $3
}

#$1 除数
#$2 被除数
#函数: 向上去整除法
division(){
    result=$(($1 / $2))
    remainder=$(($1 % $2))

    # 如果有余数，则结果加 1
    if [ $remainder -ne 0 ]; then
        result=$((result + 1))
    fi
    echo $result
}

add_feature() {
    feature=$1
    file=$2
    parent_node=$(xmlstarlet sel -t -m "/*" -v "name()" "$file")
    feature_node=$(xmlstarlet sel -t -m "/*/*" -v "name()" -n "$file" | head -n 1)
    for xml in $(find portrom/images/my_product/etc/ -type f -name "*.xml");do
        if  grep -nq "$feature" $xml ; then
        blue "功能${feature}已存在，跳过" "Feature $feature already exists, skipping..."
            return
        fi
    done
    if [ -f $file ] ; then
        blue "添加功能: $feature" "Adding feature $feature"
        sed -i "/<\/$parent_node>/i\\\t\\<$feature_node name=\"$feature\" \/>" "$file"
    fi
}

remove_feature() {
    feature=$1
    for file in $(find portrom/images/my_product/etc/ -type f -name "*.xml");do
        if  grep -nq "$feature" $file ; then
            blue "删除$feature..." "Deleting $feature from $(basename $file)..."
            sed -i "/name=\"$feature/d" "$file"
        fi
    done
}

