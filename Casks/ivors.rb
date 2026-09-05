cask "ivors" do
  version "1.4.0"
  sha256 "ee96b5a2682c8fd8217863c2ce87bf873533df7068a662bf71f038333ab4f7cf"

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
