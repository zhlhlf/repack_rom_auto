# 移植包的修复的修改在此进行
# 当前在根工作区


rm -rf portrom/images/my_manifest
cp -rf baserom/images/my_manifest portrom/images/
cp -rf baserom/images/config/my_manifest_* portrom/images/config/
sed -i "s/ro.build.display.id=.*/ro.build.display.id=${target_display_id}/g" portrom/images/my_manifest/build.prop


rm -rf portrom/images/product/etc/auto-install*
rm -rf portrom/images/system/verity_key
rm -rf portrom/images/vendor/verity_key
rm -rf portrom/images/product/verity_key
rm -rf portrom/images/system/recovery-from-boot.p
rm -rf portrom/images/vendor/recovery-from-boot.p
rm -rf portrom/images/product/recovery-from-boot.p


#sed -i -e '$a\'$'\n''persist.adb.notify=0' portrom/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.usb.config=mtp,adb' portrom/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.disable_rescue=true' portrom/images/system/system/build.prop

# fix bootloop
cp -rf baserom/images/my_product/etc/extension/sys_game_manager_config.json portrom/images/my_product/etc/extension/

cp -rf baserom/images/my_product/build.prop portrom/images/my_product/build.prop

cp -rf baserom/images/my_product/app/com.oplus.vulkanLayer portrom/images/my_product/app/
cp -rf baserom/images/my_product/app/com.oplus.gpudrivers.sm8250.api30 portrom/images/my_product/app/


cp -rf baserom/images/my_product/etc/permissions/android.hardware.sensor.light.xml portrom/images/my_product/etc/permissions/
cp -rf  baserom/images/my_product/etc/permissions/oplus.feature.android.xml  portrom/images/my_product/etc/permissions/
cp -rf  baserom/images/my_product/etc/permissions/* portrom/images/my_product/etc/permissions/
cp -rf  baserom/images/my_product/etc/refresh_rate_config.xml portrom/images/my_product/etc/refresh_rate_config.xml
cp -rf  baserom/images/my_product/non_overlay portrom/images/my_product/non_overlay
cp -rf  baserom/images/my_product/etc/sys_resolution_switch_config.xml portrom/images/my_product/etc/sys_resolution_switch_config.xml

 # Camera
cp -rf  baserom/images/my_product/etc/camera/* portrom/images/my_product/etc/camera
cp -rf  baserom/images/my_product/vendor/etc/* portrom/images/my_product/vendor/etc/

rm -rf  portrom/images/my_product/priv-app/*
rm -rf  portrom/images/my_product/app/OplusCamera
cp -rf baserom/images/my_product/priv-app/* portrom/images/my_product/priv-app

cp -rf  baserom/images/my_product/product_overlay/*  portrom/images/my_product/product_overlay/

# bootanimation
cp -rf baserom/images/my_product/media/bootanimation/* portrom/images/my_product/media/bootanimation/

rm -rf  portrom/images/my_product/overlay/*"${port_my_product_type}".apk
for overlay in $(find baserom/images/ -type f -name "*${base_my_product_type}*".apk);do
    cp -rf $overlay portrom/images/my_product/overlay/
done
baseCarrierConfigOverlay=$(find baserom/images/ -type f -name "CarrierConfigOverlay*.apk")
portCarrierConfigOverlay=$(find portrom/images/ -type f -name "CarrierConfigOverlay*.apk")
if [ -f "${baseCarrierConfigOverlay}" ] && [ -f "${portCarrierConfigOverlay}" ];then
    blue "正在替换 [CarrierConfigOverlay.apk]" "Replacing [CarrierConfigOverlay.apk]"
    rm -rf ${portCarrierConfigOverlay}
    cp -rf ${baseCarrierConfigOverlay} $(dirname ${portCarrierConfigOverlay})
fi

# fix fingerprint & face unlock
for feature in android.hardware.biometrics.face android.hardware.fingerprint;do
    if ! xmlstarlet sel -t -c "//permissions/feature[@name='$feature']"  portrom/images/my_product/etc/permissions/com.oplus.android-features.xml  >/dev/null 2>&1;then 
        echo "Adding feature $feature"
        xmlstarlet ed -L -s "//permissions" -t elem -n feature -v "" \
            -i "//permissions/feature[last()]" -t attr -n "name" -v "$feature" portrom/images/my_product/etc/permissions/com.oplus.android-features.xml

    fi
done


#自定义替换

#Devices/机型代码/overlay 按照镜像的目录结构，可直接替换目标。
if [[ -d "devices/${base_product_device}/overlay" ]]; then
    cp -rf devices/${base_product_device}/overlay/* portrom/images/
else
    yellow "devices/${base_product_device}/overlay 未找到" "devices/${base_product_device}/overlay not found" 
fi

#Unlock AI CAll
apk=`find portrom/images -name "HeyTapSpeechAssist.apk"`
patch_smali "$apk" "jc/a.smali tc/a.smali" "$port_rom_model" "$base_rom_model"


# 后面将开始打包等一系列操作
