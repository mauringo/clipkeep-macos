cask "clipboard-assistant" do
  version "1.6.1"
  sha256 "23c46104f8a99a59491ffa74c1926c319208d19cbacc1b5df85cfe1eee3dd626"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "Clipboard Assistant.app"
end
