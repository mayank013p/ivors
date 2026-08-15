cask "ivors" do
  version "1.4.0"
  sha256 :no_check

  url "https://raw.githubusercontent.com/mayank013p/ivors_web/main/public/downloads/Ivors-macOS.zip"
  name "Ivors"
  desc "Dynamic Island for macOS"
  homepage "https://github.com/mayank013p/ivors"

  app "Ivors.app"

  zap trash: [
    "~/Library/Preferences/com.mayank.ivors.plist",
    "~/Library/Saved Application State/com.mayank.ivors.savedState",
  ]
end
