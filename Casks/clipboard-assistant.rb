cask "clipboard-assistant" do
  version "1.7.0"
  sha256 "b9303dabe0f7e463a4d6077349c68db01ba6df5f56be49df26b294ea2fd838dc"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Clipboard Assistant.app"
end
