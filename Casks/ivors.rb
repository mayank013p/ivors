cask "ivors" do
  version "1.4.0"
  sha256 "e961f8b3a6342eefc98c3a0882d5c88ce16d12331520be55f4736addcf9377f3"

  url "https://raw.githubusercontent.com/mayank013p/ivors/main/Ivors-macOS.zip"
  name "Ivors"
  desc "Dynamic Island & Notch Productivity HUD for macOS"
  homepage "https://github.com/mayank013p/ivors"

  app "Ivors.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Ivors.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.mayank.ivors.plist",
    "~/Library/Saved Application State/com.mayank.ivors.savedState",
  ]
end
