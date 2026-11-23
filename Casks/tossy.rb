cask "tossy" do
  version "2.1.0"
  sha256 "118a3a86fa300fe511b1cb22420aa91dde14bb8e0cd2476336916401eb11a34c"

  url "https://github.com/thatonemacosdev/tossy-macos/releases/download/v#{version}/Tossy-#{version}-macOS.zip"
  name "Tossy"
  desc "Ultra-fast native macOS batch media, document, and archive converter"
  homepage "https://thatonemacosdev.github.io/tossy-macos/"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Tossy.app"

  zap trash: [
    "~/Library/Application Support/Tossy",
    "~/Library/Preferences/com.easyconvert.app.plist",
    "~/Library/Caches/com.easyconvert.app",
  ]
end
