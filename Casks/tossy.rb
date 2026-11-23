cask "tossy" do
  version "2.2.0"
  sha256 "1034c54a7d4836f122d8be6bd6feb81ef656c02cd46910c1fea21a2981029848"

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
