cask "tossy" do
  version "2.2.0"
  sha256 "27591faac5c6fc01a9b86e83bb434aaa4dfbc1d17fe2d49f29a2d2ee08ef6cf8"

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
