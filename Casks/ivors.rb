cask "ivors" do
  version "1.4.0"
  sha256 "00fd0a74c7a1105d5d063cc2ce1e02d696e68a425f56419e6a9f22c105510b25"

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
