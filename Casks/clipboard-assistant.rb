cask "clipboard-assistant" do
  version "1.4.0"
  sha256 "0c4dca5fd1a2a226d8b7410ffd171e3c9f496d6368aee302599f3c55eb75e400"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "Clipboard Assistant.app"
end
