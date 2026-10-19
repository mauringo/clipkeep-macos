cask "clipboard-assistant" do
  version "1.6.2"
  sha256 "8bb7d70469a87323ed7110bc7be8d1685e1322256af309c67b66386c846ea8d9"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Clipboard Assistant.app"
end
