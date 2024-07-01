
portrom_version_security_patch=$(< portrom/images/my_manifest/build.prop grep "ro.build.version.security_patch" |awk 'NR==1' |cut -d '=' -f 2 )

rm -rf portrom/images/my_manifest
cp -rf baserom/images/my_manifest portrom/images/
cp -rf baserom/images/config/my_manifest_* portrom/images/config/
sed -i "s/ro.build.display.id=.*/ro.build.display.id=${target_display_id}/g" portrom/images/my_manifest/build.prop
sed -i "s/ro.build.version.security_patch=.*/ro.build.version.security_patch=${portrom_version_security_patch}/g" portrom/images/my_manifest/build.prop

rm -rf portrom/images/product/etc/auto-install*
rm -rf portrom/images/system/verity_key
rm -rf portrom/images/vendor/verity_key
rm -rf portrom/images/product/verity_key
rm -rf portrom/images/system/recovery-from-boot.p
rm -rf portrom/images/vendor/recovery-from-boot.p
rm -rf portrom/images/product/recovery-from-boot.p

# fix bootloop
cp -rf baserom/images/my_product/etc/extension/sys_game_manager_config.json portrom/images/my_product/etc/extension/

props=("ro.oplus.display.screenSizeInches.primary" "ro.display.rc.size" "ro.oplus.display.rc.size" "ro.oppo.screen.heteromorphism" "ro.oplus.display.screen.heteromorphism" "ro.oppo.screenhole.positon" "ro.oplus.display.screenhole.positon" "ro.lcd.display.screen.underlightsensor.region" "ro.oplus.lcd.display.screen.underlightsensor.region")

props+=("ro.display.brightness.hbm_xs" "ro.display.brightness.hbm_xs_min" "ro.display.brightness.hbm_xs_max" "ro.oplus.display.brightness.xs" "ro.oplus.display.brightness.ys" "ro.oplus.display.brightness.hbm_ys" "ro.oplus.display.brightness.default_brightness" "ro.oplus.display.brightness.normal_max_brightness" "ro.oplus.display.brightness.max_brightness" "ro.oplus.display.brightness.normal_min_brightness" "ro.oplus.display.brightness.min_light_in_dnm" "ro.oplus.display.brightness.smooth" "ro.display.brightness.brightness.mode" "ro.display.brightness.mode.exp.per_20" "ro.vendor.display.AIRefreshRate.brightness" "ro.oplus.display.dwb.threshold" "ro.oplus.display.colormode.vivid" "ro.oplus.display.colormode.soft" "ro.oplus.display.colormode.cinema" "ro.oplus.display.colormode.colorful" )

for prop in "${props[@]}" ; do
    base_prop_value=$(grep "$prop=" baserom/images/my_product/build.prop | cut -d '=' -f2)
    target_prop_value=$(grep "$prop=" portrom/images/my_product/build.prop | cut -d '=' -f2)
    if [[ -n $target_prop_value ]];then
        sed -i "s|${prop}=.*|${prop}=${base_prop_value}|g" portrom/images/my_product/build.prop
    else
        echo "${prop}=$base_prop_value" >> portrom/images/my_product/build.prop
    fi
done

sed -i "s/persist.oplus.software.audio.right_volume_key=.*/persist.oplus.software.audio.right_volume_key=false/g" portrom/images/my_product/build.prop
sed -i "s/persist.oplus.software.alertslider.location=.*/persist.oplus.software.alertslider.location=/g" portrom/images/my_product/build.prop

cp -rf baserom/images/my_product/app/com.oplus.vulkanLayer portrom/images/my_product/app/
cp -rf baserom/images/my_product/app/com.oplus.gpudrivers.sm8250.api30 portrom/images/my_product/app/

rm -rf portrom/images/my_product/etc/permissions/*
cp -rf baserom/images/my_product/etc/permissions/* portrom/images/my_product/etc/permissions/

rm -rf portrom/images/my_product/etc/extension/*
cp -rf baserom/images/my_product/etc/extension/* portrom/images/my_product/etc/extension/
cp -rf  baserom/images/my_product/etc/refresh_rate_config.xml portrom/images/my_product/etc/refresh_rate_config.xml
cp -rf  baserom/images/my_product/non_overlay portrom/images/my_product/non_overlay
cp -rf  baserom/images/my_product/etc/sys_resolution_switch_config.xml portrom/images/my_product/etc/sys_resolution_switch_config.xml
add_feature "com.android.systemui.support_media_show" portrom/images/my_product/etc/extension/com.oplus.app-features.xml

add_feature "oplus.software.support_blockable_animation" portrom/images/my_product/etc/extension/com.oplus.oplus-feature.xml

add_feature "oplus.software.support_quick_launchapp" portrom/images/my_product/etc/extension/com.oplus.oplus-feature.xml

features=("oplus.software.display.intelligent_color_temperature_support" "oplus.software.display.dual_sensor_support" "oplus.software.display.lock_color_temperature_in_drag_brightness_bar_support" "oplus.software.display.smart_color_temperature_rhythm_health_support" "oplus.software.display.lhdr_only_dimming_support" "oplus.software.display.screen_calibrate_100apl" "oplus.software.display.rgb_ball_support" "oplus.software.display.screen_select" "oplus.software.display.origin_roundcorner_support")

for feature in "${features[@]}" ; do 
    add_feature "$feature" "portrom/images/my_product/etc/permissions/oplus.product.display_features.xml"
done

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
        xmlstarlet ed -L -s "//permissions" -t elem -n feature -v "" -i "//permissions/feature[last()]" -t attr -n "name" -v "$feature" portrom/images/my_product/etc/permissions/com.oplus.android-features.xml

    fi
done

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
