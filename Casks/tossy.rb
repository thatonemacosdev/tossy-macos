cask "tossy" do
  version "2.2.0"
  sha256 "1e6a6c8542d3452c0fba6a8c8c3cef04be1f506d4a79d00cd0bd5f913165c118"

  url "https://github.com/thatonemacosdev/easyconvert/releases/download/v#{version}/Tossy-v#{version}-macOS-arm64.zip"
  name "Tossy"
  desc "Ultra-fast native macOS batch media, document, and archive converter"
  homepage "https://thatonemacosdev.github.io/easyconvert/"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Tossy.app"

  zap trash: [
    "~/Library/Application Support/Tossy",
    "~/Library/Preferences/com.easyconvert.app.plist",
    "~/Library/Caches/com.easyconvert.app",
  ]
end
