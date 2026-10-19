cask "clipboard-assistant" do
  version "1.6.0"
  sha256 "cd316c951bc4b9f037017e359f0f7680e9aa820addbacf5d8cf28d018efa783d"

  url "https://github.com/mauringo/clipkeep-macos/releases/download/v#{version}/ClipboardAssistant-#{version}-arm64.zip"
  name "Clipboard Assistant"
  desc "Local clipboard history with text, image, JSON and YAML previews"
  homepage "https://github.com/mauringo/clipkeep-macos"

  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "Clipboard Assistant.app"
end
