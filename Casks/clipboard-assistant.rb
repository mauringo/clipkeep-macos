cask "clipboard-assistant" do
  version "1.7.0"
  sha256 "400b3a0ef31cf88465d4b4be7ea28ac3fe54c21a9b105648e7d89b813946f43c"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Clipboard Assistant.app"
end
