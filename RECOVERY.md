# 恢复手册：1.4 及更早版本的「设为默认播放器…」导致整机卡死

> **English version below.**
>
> ## ✅ 已在真机上验证有效
>
> 一台中招的 Mac（安全模式也只剩黑屏 + 鼠标、重启无限风火轮）用下面的
> **路线 A 全套**跑了一次，重启后**恢复正常**。
>
> ⚠️ **关键：路线 A 的四步要一起做完**，尤其是 **A5「把 App 挪走」**。
> 只清缓存、把 App 留在 `/Applications` 里，很可能重启后**再次卡死** ——
> 这正是「明明清理过、怎么还是卡」最常见的原因。
>
> ⚠️ 另一个同样常见的原因：**命令根本没跑成**。从网页 / 网盘复制多行命令时，
> 换行会被吃掉、引号会变弯引号、路径开头的 `/` 会被漏掉，而 shell **不会报错**。
> 所以：**能一行就一行**；多行就用文末那条单行 `curl` 拉脚本跑。
> 跑完务必看脚本自己打的**复核输出**（剩余缓存数 / App 是否已挪走）。

## 症状

- 点了菜单「文件 → 设为默认播放器…」之后，**整机卡死**
- 鼠标指针还能移动，但点什么都没反应（风火轮），菜单栏 / Dock / 窗口全部僵住
- **强制关机重启后，在同一位置再次卡死**，进不到可用桌面
- 严重时：**安全模式只剩黑屏 + 鼠标**，**TTY（单用户 / 控制台）里也无限风火轮**

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

### 路线 A：恢复模式（安全模式也黑屏 / 仍卡死时用这条）★

> **先说最重要的一条**：别指望「单纯新建一个管理员账户」就修好机器。
> 坏状态在磁盘上时，新账户登录后 `lsd` 照样去读它、照样卡在同一处。
> 顺序永远是：**先清磁盘上的坏库 → 再建账户 → 再重启。**
>
> 但反过来也要知道：**如果坏状态只在某个用户的域里**（`~/Library/Preferences`、
> saved state），**换账户确实能绕过它** —— 这是唯一一条不需要猜对病因就能修好的路
> （见文末「清理两轮仍卡死」）。

**A1. 进恢复模式**

- **Apple Silicon**：完全关机 → **长按电源键不放** → 出现「正在载入启动选项…」再松手 →
  点齿轮「选项」→「继续」→ 选一个管理员账户并输密码 → 菜单栏「实用工具」→「终端」
- **Intel**：关机 → 开机瞬间**按住 ⌘R** → 出现 Apple 标志后松手 →
  必要时选 `Macintosh HD` 并输密码 →「实用工具」→「终端」

**A2. 确认数据卷已挂载 / 解锁（顺手避开一个手误）**

```sh
ls /Volumes
```

看不到 `Macintosh HD - Data`，或 `ls /Volumes/"Macintosh HD - Data"/Users` 空空的 →
**FileVault 没解锁**：磁盘工具 → 选**数据卷** → 「装载」→ 输入开机密码 → 回终端。

> ⚠️ **引号里那个开头的 `/` 别丢**：
> `ls "Volumes/Macintosh HD - Data/Users/me"` ❌ 会报 `No such file or directory`，
> 因为少了 `/` 就变成相对路径了。正确写法 `"/Volumes/Macintosh HD - Data/Users/me"`。
> 下文一律用 `$D` 变量拼路径，天然带斜杠，不会犯这个错。
>
> 顺带纠正一个常见误读：`ls "$D/Users"` 打印 `.localized  Shared  <你的用户名>`
> **是正常的**（`/Users` 这一层本来就只列用户名），看到自己的用户名就说明**已经解锁**。

**A3. 先跑一次磁盘急救**

csstore 是在写入过程中被硬杀的，文件系统层面也可能留下不一致。
磁盘工具 →「显示所有设备」→ 选最里层的 `Macintosh HD - Data` →「急救」→「运行」。

终端等价写法（**先 `diskutil list` 看标识符，别照抄**）：

```sh
diskutil list
diskutil verifyVolume <数据卷标识符>
diskutil unmount  <数据卷标识符>
diskutil repairVolume <数据卷标识符>
```

**A4. 清掉 LaunchServices 坏状态 ★核心**

```sh
# 自动定位数据卷
D=""
for c in "/Volumes/Macintosh HD - Data" "/System/Volumes/Data"; do
  if [ -d "$c/private/var/db/dslocal" ]; then D="$c"; break; fi
done
echo "数据卷 = [$D]"

# 自动认用户名
ls "$D/Users"
U=$(ls "$D/Users" 2>/dev/null | grep -vxE 'Shared|Guest|\.localized' | head -1)
echo "用户名 = [$U]"
```

确认两个方括号里都是对的，再继续：

```sh
# ① 用户级 LS 偏好（主犯：里面是 SettingsStore.sql + launchservices.secure.plist）
rm -rf "$D/Users/$U/Library/Preferences/com.apple.LaunchServices"
rm -rf "$D/Users/$U/Library/Preferences/ByHost/com.apple.LaunchServices"*

# ② 系统级（26.7 上默认不存在，保险起见一起清）
rm -rf "$D/Library/Preferences/com.apple.LaunchServices"

# ③ lsd 缓存 —— 每个用户 + 每个守护进程各一份，必须全扫
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices.dv" \
     -exec rm -rf {} + 2>/dev/null
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices-*.csstore*" \
     -exec rm -rf {} + 2>/dev/null

# ④ App 残留
rm -rf "$D/Users/$U/Library/Saved Application State/cn.zxwzz.hipl.savedState"
rm -rf "$D/Users/$U/Library/Caches/FrameInterp"
rm -f  "$D/Users/$U/Library/Preferences/cn.zxwzz.hipl.plist"

# ⑤ 复查
n=$(find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices.dv" 2>/dev/null | wc -l | tr -d ' ')
echo "剩余 LS 缓存目录数 = $n   （0 才对）"
ls -d "$D/Users/$U/Library/Preferences/com.apple.LaunchServices" 2>/dev/null || echo "✅ LS 偏好已清"
```

**A5. 把 App 挪走**（用 `mv` 而不是 `rm`，万一要翻查东西还在）

```sh
mkdir -p "$D/.quarantine"
mv "$D/Applications/FrameInterp.app"  "$D/.quarantine/" 2>/dev/null
mv "$D/Applications/硬件插帧播放.app"  "$D/.quarantine/" 2>/dev/null
ls "$D/Applications" | grep -iE "frameinterp|插帧" || echo "✅ 已挪走"
```

**A6. 需要的话，在恢复模式里建一个救援管理员**

适用场景：机器上只有一个管理员账户，或原账户也进不去。

*首选 —— 让系统重新走一次初始设置向导。* 系统自己生成的账户，
权限 / ACL / 钥匙串 / FileVault 授权**全自动正确**，比手工敲 `dscl` 稳得多：

```sh
mv "$D/private/var/db/.AppleSetupDone" "$D/private/var/db/.AppleSetupDone.bak"
```

重启后机器会像新机一样询问语言 / 地区 / Apple ID —— 在「创建电脑账户」那一步
**建一个全新的管理员账户**（名字随便）。原账户和数据都还在，不会被删。
FileVault 开着时，向导会要求输入现有 FileVault 用户的密码来授权，
这一步同时会把新账户加进解锁列表 —— 正是我们想要的。

*备选 —— `dscl` 手工建。* **先跑这条自检**，能列出用户名才说明语法可用：

```sh
N="$D/private/var/db/dslocal/nodes/Default"
dscl -f "$N" localonly -list /Users      # 报 eDSUnknownNodeName / Invalid Path 就回到上一招
```

```sh
dscl -f "$N" localonly -create /Users/rescue
dscl -f "$N" localonly -create /Users/rescue RealName "Rescue Admin"
dscl -f "$N" localonly -create /Users/rescue UniqueID 650
dscl -f "$N" localonly -create /Users/rescue PrimaryGroupID 20
dscl -f "$N" localonly -create /Users/rescue NFSHomeDirectory /Users/rescue
dscl -f "$N" localonly -create /Users/rescue UserShell /bin/zsh
dscl -f "$N" localonly -passwd /Users/rescue 1234
dscl -f "$N" localonly -append /Groups/admin GroupMembership rescue
mkdir -p "$D/Users/rescue" && chown -R 650:20 "$D/Users/rescue" && chmod 700 "$D/Users/rescue"
```

> `UniqueID 650` 先确认没被占用，换一个没人用的号。手工账户登录后可能被要求
> 「创建新钥匙串」，点创建即可，正常现象。

**A7. 重启**

关掉终端 → 苹果菜单 →「重新启动」。重启后**优先用新账户登录** ——
新账户能进，说明坏东西确实都在旧账户的缓存里。

**A8. 两条兜底**

- 老账户**还是**卡 → 把它的整个偏好目录**挪走**（不是删，随时能搬回来）：
  ```sh
  mv "$D/Users/$U/Library/Preferences" "$D/Users/$U/Library/Preferences.bak"
  ```
  代价是所有 App 设置回默认；文稿、照片、桌面文件**一个都不会少**。
- 只想先保住数据 → 恢复模式终端里插上外置盘直接拷：
  ```sh
  ls /Volumes
  cp -R "$D/Users/$U/Documents" "/Volumes/备份盘/"
  ```
  FileVault 开着时拷出来的是**解密后**的文件，能直接用。

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

## 清理两轮仍卡死？别再重复第三遍

**先自查一件事**（实测中招的那台就卡在这里）：

```sh
ls "$D/Applications" | grep -iE "frameinterp|插帧"
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices*" | head
```

第一条**必须没有输出**（App 已挪走），第二条也**必须没有输出**（缓存已清）。
只要 App 还留在 `/Applications` 里，重启后 `lsd` 会再踩同一个坑 ——
**"清理过还是卡" 多半就是这个**。

两条都干净了还卡，再往下分叉：

同一个药方吃第三遍没有意义 —— 先定位层级。

**只看一件事：黑屏发生在哪一步？**

| 现象 | 含义 | 往哪走 |
|---|---|---|
| 能看到登录窗口，**输完密码后**才黑屏 / 风火轮 | 坏状态在**你的账户**里 | 换账户（下面主路） |
| **开机就黑**，连登录窗口都没有 | 已经不在账户层 | 看崩溃报告计数；全为 0 就得考虑重装 |

崩溃报告计数（恢复模式终端）：

```sh
R="$D/Users/$U/Library/Logs/DiagnosticReports"
ls "$R" 2>/dev/null | grep -icE "lsd|Finder|WindowServer|loginwindow"
```

- 有 `lsd` / `Finder` / `loginwindow` 的 `.ips` → 崩溃循环实锤，方向对
- **全为 0** → 不是"崩溃"，是"在等某个东西回话"或显示层的问题 → 换方向

### 主路（推荐）：换账户，把数据搬过去

不要跟坏状态死磕。新账户是干净的 per-user 状态，**这是唯一一条不需要猜对病因就能修好的路**。

```sh
D="/Volumes/Macintosh HD - Data"
U=$(ls "$D/Users" | grep -vxE 'Shared|Guest|\.localized' | head -1)
mv "$D/private/var/db/.AppleSetupDone" "$D/private/var/db/.AppleSetupDone.bak"
reboot
```

重启后过一遍欢迎向导，**建一个新管理员**（原账户与数据都在）。
用新账户登录进去后，把数据搬过来：

```sh
sudo cp -R "/Users/$U/Documents" ~/
sudo cp -R "/Users/$U/Desktop"   ~/
sudo chown -R "$(id -un)" ~/Documents ~/Desktop
```

> **必须 `sudo`**：macOS 家目录带 ACL，跨账户直接读常被挡 —— 所以别在 Finder 里硬拷。
> FileVault 已解锁，拷出来是明文。确认无误后旧账户**先留着当备份**。

代价：重过一遍欢迎向导 + 重设几个 App 的偏好。

### 辅路：偏好目录改名（可逆）

只想救回旧账户、又不在意设置的话，把偏好相关目录**挪走**（是 `mv` 不是 `rm`）：

```sh
mv "$D/Users/$U/Library/Preferences" "$D/Users/$U/Library/Preferences.bak"
mv "$D/Users/$U/Library/Saved Application State" "$D/Users/$U/Library/Saved Application State.bak"
```

---

---

# Recovery Guide (English)

> ## ✅ Confirmed on real hardware
>
> A wedged Mac (safe mode showing nothing but a black screen and the cursor, endless
> beachball on every reboot) was recovered by running **all of Route A** once and rebooting.
>
> ⚠️ **Do all four steps of Route A, especially A5 "move the app aside".**
> Wiping the caches while leaving the app in `/Applications` can bring the freeze
> straight back on the next boot — this is the most common reason a "cleanup" appears
> to have done nothing.
>
> ⚠️ The other equally common reason: **the commands never actually ran.** Pasting
> multi-line commands out of a web page or cloud drive eats newlines, turns quotes curly
> and drops leading slashes — and the shell **says nothing**. So: **prefer one-liners**;
> for anything longer, use the single-line `curl` at the end of this document and check
> the script's own verification output (caches remaining / app quarantined).

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

**Route A — Recovery Mode** (when Safe Mode also blacks out or still freezes). ★

> **Read this first: creating a new admin account on its own will NOT fix the machine.**
> The corrupt database sits on disk; when the new account logs in, `lsd` still reads it and
> still wedges at the same point. The order is always:
> **wipe the corrupt databases on disk → then create the account → then reboot.**

*A1. Enter Recovery Mode*

- **Apple Silicon**: shut down completely → **hold the power button** until
  "Loading startup options" appears → click the gear icon "Options" → Continue →
  pick an admin account and enter its password → menu bar "Utilities" → "Terminal"
- **Intel**: shut down → press **⌘R** immediately on power-up and hold it until the Apple
  logo appears → pick `Macintosh HD` and enter the password if asked →
  "Utilities" → "Terminal"

*A2. Make sure the Data volume is mounted*

```sh
ls /Volumes
```

No `Macintosh HD - Data`, or `ls /Volumes/"Macintosh HD - Data"/Users` comes back empty →
**FileVault is still locked**: Disk Utility → select the **Data volume** → "Mount" →
enter your password → back to Terminal.

> ⚠️ **Do not drop the leading `/` inside the quotes.**
> `ls "Volumes/Macintosh HD - Data/Users/me"` ❌ fails with *No such file or directory* —
> without the `/` it becomes a relative path. Write `"/Volumes/Macintosh HD - Data/Users/me"`.
> Everything below uses the `$D` variable, which always carries its slash.
>
> Also a common misreading: `ls "$D/Users"` printing `.localized  Shared  <your-user>`
> is **normal** (`/Users` only ever lists user names) — seeing your own name means the
> volume **is** unlocked.

*A3. Run First Aid first*

csstore was SIGKILLed mid-write, so the file system may be inconsistent too.
Disk Utility → "Show All Devices" → select the innermost `Macintosh HD - Data` →
"First Aid" → Run. Terminal equivalent (**run `diskutil list` first, don't copy the ID**):

```sh
diskutil list
diskutil verifyVolume <dataVolId>
diskutil unmount  <dataVolId>
diskutil repairVolume <dataVolId>
```

*A4. Wipe the LaunchServices corrupt state* ★ core step

```sh
# locate the Data volume
D=""
for c in "/Volumes/Macintosh HD - Data" "/System/Volumes/Data"; do
  if [ -d "$c/private/var/db/dslocal" ]; then D="$c"; break; fi
done
echo "Data volume = [$D]"

# find the user name
ls "$D/Users"
U=$(ls "$D/Users" 2>/dev/null | grep -vxE 'Shared|Guest|\.localized' | head -1)
echo "User = [$U]"
```

Once both brackets are right:

```sh
# 1. per-user LS preferences (the main culprit: SettingsStore.sql + secure.plist)
rm -rf "$D/Users/$U/Library/Preferences/com.apple.LaunchServices"
rm -rf "$D/Users/$U/Library/Preferences/ByHost/com.apple.LaunchServices"*

# 2. system-wide (absent by default on 26.7 — wiped anyway for safety)
rm -rf "$D/Library/Preferences/com.apple.LaunchServices"

# 3. lsd caches — one per user AND one per daemon, so scan them all
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices.dv" \
     -exec rm -rf {} + 2>/dev/null
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices-*.csstore*" \
     -exec rm -rf {} + 2>/dev/null

# 4. the app's own leftovers
rm -rf "$D/Users/$U/Library/Saved Application State/cn.zxwzz.hipl.savedState"
rm -rf "$D/Users/$U/Library/Caches/FrameInterp"
rm -f  "$D/Users/$U/Library/Preferences/cn.zxwzz.hipl.plist"

# 5. verify
n=$(find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices.dv" 2>/dev/null | wc -l | tr -d ' ')
echo "remaining LS cache dirs = $n   (must be 0)"
ls -d "$D/Users/$U/Library/Preferences/com.apple.LaunchServices" 2>/dev/null || echo "OK: LS prefs wiped"
```

*A5. Quarantine the app* (use `mv`, not `rm`, so you can still inspect it)

```sh
mkdir -p "$D/.quarantine"
mv "$D/Applications/FrameInterp.app"  "$D/.quarantine/" 2>/dev/null
mv "$D/Applications/硬件插帧播放.app"  "$D/.quarantine/" 2>/dev/null
ls "$D/Applications" | grep -iE "frameinterp|插帧" || echo "OK: quarantined"
```

*A6. Create a rescue admin account if you need one*

For machines with a single admin account, or when the original account can't get in either.

*Preferred — let macOS run its Setup Assistant again.* An account the system creates itself
has correct permissions, ACLs, keychain and FileVault authorisation:

```sh
mv "$D/private/var/db/.AppleSetupDone" "$D/private/var/db/.AppleSetupDone.bak"
```

On reboot macOS behaves like a new Mac and asks for language / region / Apple ID — at the
"Create a Computer Account" step, **create a brand-new admin account**. Your original account
and all data stay where they are. With FileVault on, the assistant asks for an existing
FileVault user's password to authorise the new one — which is exactly the step that adds it
to the unlock list.

*Fallback — build the account by hand with `dscl`.* **Run this self-check first**; it only
works if your user names are listed:

```sh
N="$D/private/var/db/dslocal/nodes/Default"
dscl -f "$N" localonly -list /Users      # eDSUnknownNodeName / Invalid Path → use the way above
```

```sh
dscl -f "$N" localonly -create /Users/rescue
dscl -f "$N" localonly -create /Users/rescue RealName "Rescue Admin"
dscl -f "$N" localonly -create /Users/rescue UniqueID 650
dscl -f "$N" localonly -create /Users/rescue PrimaryGroupID 20
dscl -f "$N" localonly -create /Users/rescue NFSHomeDirectory /Users/rescue
dscl -f "$N" localonly -create /Users/rescue UserShell /bin/zsh
dscl -f "$N" localonly -passwd /Users/rescue 1234
dscl -f "$N" localonly -append /Groups/admin GroupMembership rescue
mkdir -p "$D/Users/rescue" && chown -R 650:20 "$D/Users/rescue" && chmod 700 "$D/Users/rescue"
```

> Check that UID 650 is free first. A hand-built account may be asked to "create a new
> keychain" on first login — click Create, that's normal.

*A7. Reboot* — with **the new account first**. If it reaches the desktop, the bad state really
was in the old account's caches.

*A8. Two fallbacks*

- Old account still freezes → move its whole preferences folder aside (**move**, not delete):
  ```sh
  mv "$D/Users/$U/Library/Preferences" "$D/Users/$U/Library/Preferences.bak"
  ```
  You lose app settings; documents, photos and Desktop files are untouched.
- Just want the data out → plug in an external disk in Recovery Terminal and copy:
  ```sh
  ls /Volumes
  cp -R "$D/Users/$U/Documents" "/Volumes/BackupDisk/"
  ```
  With FileVault on, the copies come out **decrypted** and are directly usable.

**Route C — a second admin account.** Log in with another admin user (its per-user state is
clean), run route B's commands, then log back in to your own account.

## If Finder still misbehaves

In **Safe Mode**, run Apple's official rebuild:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user
```

Do **not** add `-kill`.

## Still frozen after two cleanup rounds?

**Check one thing first** (this is exactly where the machine we recovered got stuck):

```sh
ls "$D/Applications" | grep -iE "frameinterp|插帧"
find "$D/private/var/folders" -maxdepth 4 -name "com.apple.LaunchServices*" | head
```

The first command **must print nothing** (app moved aside) and so must the second
(caches wiped). If the app is still in `/Applications`, `lsd` walks into the same trap
on the next boot — **that is almost certainly why "I already cleaned it" didn't help**.

Only if both are clean, split by layer:

Running the same fix a third time is pointless — find the layer first.

**One question decides it: where does the black screen hit?**

| What you see | Meaning | Where to go |
|---|---|---|
| You can see the login window, and it goes black / beachballs **after** you enter the password | The bad state lives in **your account** | New account (main route below) |
| **Black from boot**, no login window at all | Not account-level any more | Check crash-report counts; if they are all zero, consider reinstalling |

```sh
R="$D/Users/$U/Library/Logs/DiagnosticReports"
ls "$R" 2>/dev/null | grep -icE "lsd|Finder|WindowServer|loginwindow"
```

An `.ips` for `lsd` / `Finder` / `loginwindow` is a crash-loop confirmation. **All zeros** means
it is not crashing — it is waiting on something, or it is a display-layer problem. Change tack.

### Main route — switch accounts and move your data over

Stop fighting the bad state. A new account has a clean per-user state, and this is the **only
route that does not require guessing the root cause**.

```sh
D="/Volumes/Macintosh HD - Data"
U=$(ls "$D/Users" | grep -vxE 'Shared|Guest|\.localized' | head -1)
mv "$D/private/var/db/.AppleSetupDone" "$D/private/var/db/.AppleSetupDone.bak"
reboot
```

Walk through the welcome assistant, **create a new administrator** (the old account and all its
data stay put), log in with it, then copy your data across:

```sh
sudo cp -R "/Users/$U/Documents" ~/
sudo cp -R "/Users/$U/Desktop"   ~/
sudo chown -R "$(id -un)" ~/Documents ~/Desktop
```

`sudo` is required: macOS home folders carry ACLs, so reading across accounts is normally
blocked — do **not** try it in Finder. With FileVault unlocked the copies come out as plaintext.
Keep the old account around as a backup.

Cost: re-running the welcome assistant and re-setting a few app preferences. Your documents,
photos and Desktop files are untouched.
