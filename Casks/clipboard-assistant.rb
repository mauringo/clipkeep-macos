cask "clipboard-assistant" do
  version "1.5.0"
  sha256 "67e0c5cb0009f40c64971e2a917889c7c22632076fd7e635d121aeb39b29b792"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "Clipboard Assistant.app"
end
