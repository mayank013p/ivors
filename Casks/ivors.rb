cask "ivors" do
  version "1.4.0"
  sha256 "eec7b657a4660550a854db0db82b53d3ab28c10b1cca0092225c84d8af31dd06"

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
