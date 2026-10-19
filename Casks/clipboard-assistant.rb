cask "clipboard-assistant" do
  version "1.3.0"
  sha256 "95abc64910277a80d7dd5f3bf92901bf4c71839b8777ac7f80b02292c1e2446b"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "Clipboard Assistant.app"
end
