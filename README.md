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

Apple Silicon Mac 可通过 Homebrew 安装：

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
