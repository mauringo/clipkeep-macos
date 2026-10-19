cask "clipboard-assistant" do
  version "1.7.0"
  sha256 "7245e65aff4c04289f287367fedbc1b99b5995e8c36ed72c24c1ea39dc68dc9e"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Clipboard Assistant.app"
end
