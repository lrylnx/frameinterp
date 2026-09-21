# 恢复手册：1.4 及更早版本的「设为默认播放器…」导致整机卡死

> **English version below.**

## 症状

- 点了菜单「文件 → 设为默认播放器…」之后，**整机卡死**
- 鼠标指针还能移动，但点什么都没反应（风火轮），菜单栏 / Dock / 窗口全部僵住
- **强制关机重启后，在同一位置再次卡死**，进不到可用桌面

## 原因

1.4 及更早版本为了避开 macOS 26.4 起「改一次默认程序弹一次确认框」的行为，
走了这条路：

1. 绕过官方 API，**直接写 Apple 的 `com.apple.LaunchServices` 偏好**；
2. 然后 **`killall -9 lsd`** —— 用 SIGKILL 硬杀 LaunchServices 守护进程。

`lsd` 负责回答「哪种文件用哪个 App 打开」。`SIGKILL` 不给它任何收尾机会，
LaunchServices 的数据库（csstore）会在写到一半时被杀死，**留下持久化的坏状态**。
Finder、Dock、登录流程全都阻塞在等 `lsd` 回话上，于是整机卡死；
又因为坏状态在磁盘上，**每次开机重演**。

> Apple 官方的重置手段是 `lsregister -kill`（有握手、能优雅收尾）。
> 硬杀（`killall -9`）不是"更彻底"，是砸机器。

**1.5 已彻底移除这段代码**，并且该功能现在带备份 / 撤销。

---

## 恢复步骤

两条路，先试 B（省事），不行再走 A（更可靠）。

### 路线 B：安全模式

1. 关机 → **按住电源键不放**，直到出现「正在载入启动选项…」→ 松手
2. 选中启动磁盘 → **按住 Shift** → 点「在安全模式下继续」→ 松开 Shift
3. 能操作桌面的话，打开「终端」，执行（**不要 kill 任何守护进程**）：

```sh
sudo rm -rf /Applications/FrameInterp.app /Applications/硬件插帧播放.app
rm -rf ~/Library/Preferences/com.apple.LaunchServices
rm -rf ~/Library/Saved\ Application\ State/cn.zxwzz.hipl.savedState
rm -rf ~/Library/Caches/FrameInterp
sudo find /private/var/folders -type d -name "com.apple.LaunchServices.dv" -exec rm -rf {} + 2>/dev/null
```

4. **正常重启**（别一直待在安全模式里）

### 路线 A：恢复模式（安全模式也卡死时用这条）

1. 关机 → **按住电源键不放** →「正在载入启动选项…」→ 点「选项」→「继续」，
   输入开机密码，进入 **macOS 恢复**
2. 顶部菜单「实用工具」→「终端」
3. 挂载数据卷。`ls /Volumes` 看不到形如 `Macintosh HD - Data` 的卷，
   就先开「磁盘工具」选中**数据卷**点「装载…」并输入密码；提示只读就 `mount -uw "<卷路径>"`

```sh
D="/Volumes/Macintosh HD - Data"          # 按 ls /Volumes 的实际名字改
U=$(ls "$D/Users" | grep -v Shared | head -1)

# ① 删 App（/Applications 实际位于数据卷）
rm -rf "$D/Applications/FrameInterp.app"
rm -rf "$D/Applications/硬件插帧播放.app"

# ② 清掉被写坏的「默认打开方式」偏好（会被系统自动重建）
rm -rf "$D/Users/$U/Library/Preferences/com.apple.LaunchServices"

# ③ 清掉 LaunchServices 数据库缓存 —— 关键，就是把 Finder 顶死的那个
find "$D/private/var/folders" -type d -name "com.apple.LaunchServices.dv" -exec rm -rf {} + 2>/dev/null

# ④ 清 App 残留
rm -rf "$D/Users/$U/Library/Saved Application State/cn.zxwzz.hipl.savedState"
rm -rf "$D/Users/$U/Library/Caches/FrameInterp"
rm -f  "$D/Users/$U/Library/Preferences/cn.zxwzz.hipl.plist"

# ⑤ 复查
ls "$D/Applications" | grep -iE "frameinterp|插帧" || echo "✅ App 已清掉"
ls -d "$D/Users/$U/Library/Preferences/com.apple.LaunchServices" 2>/dev/null || echo "✅ LS 偏好已清"
ls -d "$D/private/var/folders"/*/*/0/com.apple.LaunchServices.dv 2>/dev/null || echo "✅ LS 缓存已清"
```

4. 关掉终端 → 苹果菜单 →「重新启动」

### 路线 C：还有第二个管理员账号

登录窗口用另一个管理员账号登进去（per-user 状态是干净的），
执行路线 B 的命令，然后回自己的账号。

---

## 恢复后自查

```sh
pgrep -l lsd        # 应该有 lsd 在跑
open -a Finder      # Finder 能正常起来
```

Finder 行为仍异常（图标不对、双击没反应）的话，在**安全模式**下补一条官方重建：

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user
```

> 别加 `-kill`。已经被杀 `lsd` 坑过一次了。

---

## 以后怎么设默认播放器

- **升级到 1.5**，菜单「文件 → 设为默认播放器…」（官方 API + 可撤销）
- 或者自己来：右键视频 →「显示简介」→「打开方式」→ 选 FrameInterp →「全部更改…」

---

---

# Recovery Guide (English)

## Symptoms

- After clicking *File → Set as Default Player…*, **the whole machine freezes**
- The cursor still moves, but nothing responds (spinning beachball); menu bar, Dock and
  all windows are stuck
- **After a force restart it freezes again at the same point** — you can't reach a usable desktop

## Cause

To dodge the "one confirmation dialog per content type" behaviour introduced in macOS 26.4,
version 1.4 and earlier:

1. Bypassed the official API and **wrote Apple's `com.apple.LaunchServices` preferences directly**;
2. Then ran **`killall -9 lsd`** — hard-killing the LaunchServices daemon with SIGKILL.

`lsd` answers "which app opens which file". SIGKILL gives it no chance to flush, so the
LaunchServices database (csstore) is killed mid-write, **leaving a persistent corrupt state**.
Finder, the Dock and the login flow all block waiting for `lsd`, which freezes the machine —
and because the bad state is on disk, **it repeats on every boot**.

**1.5 removes that code entirely**, and the feature now backs up and can be undone.

## Recovery

Try route B first; if safe mode also freezes, use route A.

**Route B — Safe Mode.** Shut down → hold the power button until "Loading startup options"
appears → select the startup disk → **hold Shift** → "Continue in Safe Mode". Then in Terminal
(**do not kill any daemon**):

```sh
sudo rm -rf /Applications/FrameInterp.app /Applications/硬件插帧播放.app
rm -rf ~/Library/Preferences/com.apple.LaunchServices
rm -rf ~/Library/Saved\ Application\ State/cn.zxwzz.hipl.savedState
rm -rf ~/Library/Caches/FrameInterp
sudo find /private/var/folders -type d -name "com.apple.LaunchServices.dv" -exec rm -rf {} + 2>/dev/null
```

Then reboot normally.

**Route A — Recovery Mode** (when safe mode also freezes). Shut down → hold the power button
→ "Options" → Continue → password → **macOS Recovery**. Utilities → Terminal. Mount the Data
volume (use Disk Utility → Mount if it isn't listed; `mount -uw` if read-only), then:

```sh
D="/Volumes/Macintosh HD - Data"          # adjust to the real name from `ls /Volumes`
U=$(ls "$D/Users" | grep -v Shared | head -1)

rm -rf "$D/Applications/FrameInterp.app" "$D/Applications/硬件插帧播放.app"
rm -rf "$D/Users/$U/Library/Preferences/com.apple.LaunchServices"
find "$D/private/var/folders" -type d -name "com.apple.LaunchServices.dv" -exec rm -rf {} + 2>/dev/null
rm -rf "$D/Users/$U/Library/Saved Application State/cn.zxwzz.hipl.savedState"
rm -rf "$D/Users/$U/Library/Caches/FrameInterp"
rm -f  "$D/Users/$U/Library/Preferences/cn.zxwzz.hipl.plist"
```

Then reboot.

**Route C — a second admin account.** Log in with another admin user (its per-user state is
clean), run route B's commands, then log back in to your own account.

## If Finder still misbehaves

In **Safe Mode**, run Apple's official rebuild:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user
```

Do **not** add `-kill`.
