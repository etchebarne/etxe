#!/usr/bin/env bash

etxe_configure_plasma() {
  local layout_dir look_and_feel_dir
  layout_dir="$ETXE_MOUNT/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents"
  look_and_feel_dir="$ETXE_MOUNT/usr/share/plasma/look-and-feel/org.etxe.desktop"

  etxe_log "Configuring Plasma defaults"

  install -D -m 0644 "$ETXE_PATH/assets/plasma/look-and-feel/org.etxe.desktop/metadata.json" \
    "$look_and_feel_dir/metadata.json"
  install -D -m 0644 "$ETXE_PATH/assets/plasma/look-and-feel/org.etxe.desktop/contents/splash/Splash.qml" \
    "$look_and_feel_dir/contents/splash/Splash.qml"
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-icon.svg" \
    "$look_and_feel_dir/contents/splash/images/etxe-icon.svg"

  install -d -m 0755 "$ETXE_MOUNT/etc/xdg" "$ETXE_MOUNT/etc/skel/.config"
  for ksplashrc in "$ETXE_MOUNT/etc/xdg/ksplashrc" "$ETXE_MOUNT/etc/skel/.config/ksplashrc"; do
    cat >"$ksplashrc" <<'EOF'
[KSplash]
Engine=KSplashQML
Theme=org.etxe.desktop
EOF
  done

  install -d -m 0755 "$layout_dir"
  cat >"$layout_dir/layout.js" <<'EOF'
var panel = new Panel
var panelScreen = panel.screen

panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2)

const maximumAspectRatio = 21/9;
if (panel.formFactor === "horizontal") {
    const geo = screenGeometry(panelScreen);
    const maximumWidth = Math.ceil(geo.height * maximumAspectRatio);

    if (geo.width > maximumWidth) {
        panel.alignment = "center";
        panel.minimumLength = maximumWidth;
        panel.maximumLength = maximumWidth;
    }
}

var kickoff = panel.addWidget("org.kde.plasma.kickoff")
kickoff.currentConfigGroup = ["General"]
kickoff.writeConfig("icon", "etxe-icon-symbolic")
panel.addWidget("org.kde.plasma.pager")

var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", "applications:org.kde.dolphin.desktop,applications:org.kde.discover.desktop,applications:firefox.desktop")

panel.addWidget("org.kde.plasma.marginsseparator")

var langIds = ["as", "bn", "bo", "brx", "doi", "gu", "hi", "ja", "kn", "ko", "kok", "ks", "lep", "mai", "ml", "mni", "mr", "ne", "or", "pa", "sa", "sat", "sd", "si", "ta", "te", "th", "ur", "vi", "zh_CN", "zh_TW"]

if (langIds.indexOf(languageId) != -1) {
    panel.addWidget("org.kde.plasma.kimpanel");
}

panel.addWidget("org.kde.plasma.systemtray")
panel.addWidget("org.kde.plasma.digitalclock")
panel.addWidget("org.kde.plasma.showdesktop")
EOF
}

etxe_configure_plasma
