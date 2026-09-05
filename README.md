# Clipboard History for macOS

一个使用 Go 与 AppKit 编写的 macOS 菜单栏剪贴板历史工具。它只保存文本内容到本机，不上传数据。

## 功能

- 自动记录最近 100 条文本剪贴板内容；
- 使用 `⌘⇧V` 打开历史记录；
- 搜索并选择历史项；
- 将选择的内容写回系统剪贴板，并尝试自动粘贴到此前的输入位置；
- 历史数据保存在 `~/Library/Application Support/ClipboardHistory/history.json`。

## 前置条件

- macOS；
- Go 1.22 或更新版本；
- Xcode Command Line Tools（提供 AppKit 所需的编译器和 macOS SDK）。如未安装，执行：

  ```sh
  xcode-select --install
  ```

## Homebrew 安装

发布首个 GitHub Release 后，Apple Silicon Mac 可通过：

```sh
brew tap IBRIGHTMOON/clipboard
brew install --cask IBRIGHTMOON/clipboard/clipboard-history
```

安装后从「应用程序」启动 **Clipboard History**，并在「系统设置 → 隐私与安全性 → 辅助功能」授予它权限。当前 Cask 仅提供 Apple Silicon（arm64）构建。

## 在当前电脑运行

在项目目录中运行：

```sh
go run .
```

或构建为命令行可执行文件：

```sh
go build -o clipboard-history .
./clipboard-history
```

> 直接运行可执行文件时，应在「系统设置 → 隐私与安全性 → 辅助功能」中授权该可执行文件或其启动终端，才能使用全局快捷键及自动粘贴。

## 在另一台 Mac 安装 App

先把整个项目目录复制到另一台电脑，或从你的 Git 仓库克隆源码。以下命令可在任意项目位置执行：

```sh
cd /path/to/clipboard

mkdir -p "$HOME/Applications/ClipboardHistory.app/Contents/MacOS"
cp packaging/Info.plist "$HOME/Applications/ClipboardHistory.app/Contents/Info.plist"

go build -o "$HOME/Applications/ClipboardHistory.app/Contents/MacOS/clipboard-history" .
codesign --force --deep --sign - --identifier com.yang.clipboard-history \
  "$HOME/Applications/ClipboardHistory.app"

open "$HOME/Applications/ClipboardHistory.app"
```

该命令会把 App 安装到 `~/Applications/ClipboardHistory.app`。它是菜单栏工具，不会出现在 Dock；启动后按 `⌘⇧V` 即可使用。

### 必须授予辅助功能权限

首次安装或重新构建后，请到「系统设置 → 隐私与安全性 → 辅助功能」：

1. 点击 `+`；
2. 按 `⌘⇧G`；
3. 输入 `~/Applications/ClipboardHistory.app`；
4. 选择 App 并开启开关；
5. 退出并重新打开 App。

此权限用于全局快捷键与自动模拟 `⌘V`。如果开关显示已启用但自动粘贴无效，请移除该条目，再按上述步骤重新添加。每次对 App 重新签名后都可能需要重新授权。

## 更新

用新源码重复「在另一台 Mac 安装 App」中的构建与签名命令，然后退出并重新打开 App。签名更新后，请检查辅助功能权限是否仍然生效。

## 退出与卸载

退出当前进程：

```sh
pkill clipboard-history
```

卸载 App：删除 `~/Applications/ClipboardHistory.app`。如要一并删除历史记录，再删除 `~/Library/Application Support/ClipboardHistory/history.json`。

## 开机启动

当前版本**不配置**开机启动。若需要后台登录自启，可自行创建 macOS LaunchAgent；注意应授权实际被 LaunchAgent 启动的程序的辅助功能权限。

## Homebrew

当前项目尚未发布 Homebrew Cask。要支持 `brew install --cask`，还需要将签名后的 `.app` 发布到可访问的 Release 地址，并维护一个 Homebrew Cask 配方。
