#!/bin/sh
# ==============================================================
#  FrameInterp / LaunchServices 卡死 —— 救援脚本
#  在「恢复模式 → 终端」里运行
#
#     sh r.sh         只看诊断，不改任何文件（先用这个）
#     sh r.sh fix     执行修复
#
#  修复只碰 LaunchServices 相关的状态文件与肇事 App，
#  不碰你的文稿 / 桌面 / 照片 / 账户。
# ==============================================================

MODE="${1:-diag}"

echo "=============================================="
echo " FrameInterp / LaunchServices 救援"
echo " 模式: $MODE"
echo "=============================================="

# ---------- 定位数据卷 ----------
D=""
for c in "/Volumes/Macintosh HD - Data" "/System/Volumes/Data"; do
  if [ -d "$c/private/var/db/dslocal" ]; then D="$c"; break; fi
done
if [ -z "$D" ]; then
  for c in /Volumes/*; do
    if [ -d "$c/private/var/db/dslocal" ]; then D="$c"; break; fi
  done
fi

echo
echo "### 1. 数据卷"
echo "[$D]"
if [ -z "$D" ]; then
  echo "!! 没找到数据卷 —— FileVault 多半还没解锁。"
  echo "   打开「磁盘工具」→ 左边选【数据卷】→ 点【装载】→ 输入开机密码，"
  echo "   然后回到终端重跑本脚本。"
  exit 1
fi

echo
echo "### 2. 磁盘空间（可用空间为 0 会导致整机卡死，重点看这一项）"
df -h

echo
echo "### 3. 用户列表"
ls "$D/Users"

echo
echo "### 4. 坏状态残留：LaunchServices"
find "$D/Users" -maxdepth 4 -name "com.apple.LaunchServices*" 2>/dev/null | head -30
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices*" 2>/dev/null | head -30

echo
echo "### 5. 崩溃报告目录（最近 20 个）"
ls -t "$D/Library/Logs/DiagnosticReports/" 2>/dev/null | head -20

echo
echo "### 6. 关键进程崩溃报告计数（不为 0 就是它在崩）"
for k in lsd Finder Dock WindowServer loginwindow launchd; do
  n=$(ls "$D/Library/Logs/DiagnosticReports/" 2>/dev/null | grep -ci -- "$k")
  echo "  $k .. $n"
done

echo
echo "### 7. 日志体积"
du -sh "$D/Library/Logs" 2>/dev/null
du -sh "$D/private/var/db/diagnostics" 2>/dev/null

# ---------- 到此为止：诊断模式不写盘 ----------
if [ "$MODE" != "fix" ]; then
  echo
  echo "=============================================="
  echo " 以上是只读诊断，没有改动任何文件。"
  echo " 要执行修复，请运行：   sh $0 fix"
  echo "=============================================="
  exit 0
fi

echo
echo "=============================================="
echo " 开始修复"
echo "=============================================="

echo "--- ① 各用户的 LaunchServices 偏好与 App 残留"
for u in $(ls "$D/Users" 2>/dev/null | grep -vxE 'Shared|Guest|\.localized'); do
  echo "    清理用户: $u"
  rm -rf "$D/Users/$u/Library/Preferences/com.apple.LaunchServices"
  rm -rf "$D/Users/$u/Library/Preferences/ByHost/com.apple.LaunchServices"*
  rm -rf "$D/Users/$u/Library/Saved Application State/cn.zxwzz.hipl.savedState"
  rm -rf "$D/Users/$u/Library/Caches/FrameInterp"
  rm -f  "$D/Users/$u/Library/Preferences/cn.zxwzz.hipl.plist"
done

echo "--- ② 系统级偏好"
rm -rf "$D/Library/Preferences/com.apple.LaunchServices"

echo "--- ③ lsd 缓存（每个用户 + 每个守护进程各一份，必须全扫）"
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices.dv" -exec rm -rf {} + 2>/dev/null
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices-*.csstore*" -exec rm -rf {} + 2>/dev/null

echo "--- ④ 把肇事 App 挪到 .quarantine（不是删除，随时能拿回来）"
mkdir -p "$D/.quarantine"
if [ -e "$D/Applications/FrameInterp.app" ]; then
  mv "$D/Applications/FrameInterp.app" "$D/.quarantine/" && echo "    FrameInterp.app 已挪走"
fi
if [ -e "$D/Applications/硬件插帧播放.app" ]; then
  mv "$D/Applications/硬件插帧播放.app" "$D/.quarantine/" && echo "    硬件插帧播放.app 已挪走"
fi

echo
echo "### 复查"
n=$(find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices.dv" 2>/dev/null | wc -l | tr -d ' ')
echo "  剩余 lsd 缓存目录: $n   （0 才对）"
ls "$D/Applications" 2>/dev/null | grep -iE "frameinterp|插帧" || echo "  肇事 App: 已挪走"
ls -d "$D/Users"/*/Library/Preferences/com.apple.LaunchServices 2>/dev/null || echo "  用户级 LS 偏好: 已清"
echo "  系统级 LS 偏好:  $( [ -d "$D/Library/Preferences/com.apple.LaunchServices" ] && echo 仍在 || echo 已清 )"

echo
echo "=============================================="
echo " 修复完成。接着执行:   reboot"
echo
echo " 如果重启后【还是】卡死，说明坏的不止 LaunchServices。"
echo " 下一步试：恢复模式 →「重新安装 macOS」（默认保留用户数据）。"
echo " 再不行就必须抹掉重装 —— 但请先插外置硬盘把文档拷出来。"
echo "=============================================="
