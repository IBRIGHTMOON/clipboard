cask "clipboard-history" do
  version "0.1.0"

  on_arm do
    sha256 "d28a42e4476b3a9311389037cc0363d9d3eb87c9e7c08617a580118f9d6ee030"
    url "https://github.com/IBRIGHTMOON/clipboard/releases/download/v#{version}/ClipboardHistory-#{version}-arm64.zip"
  end

  depends_on arch: :arm64
  name "Clipboard History"
  desc "Text clipboard history manager for macOS"
  homepage "https://github.com/IBRIGHTMOON/clipboard"

  app "ClipboardHistory.app"
end
