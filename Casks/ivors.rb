cask "ivors" do
  version "1.4.0"
  sha256 "e79177508f72734d70adb6f796df7cb43661cd09203d484a326c998a2101c4e2"

  url "https://raw.githubusercontent.com/mayank013p/ivors/main/Ivors-macOS.zip"
  name "Ivors"
  desc "Dynamic Island & Notch Productivity HUD for macOS"
  homepage "https://github.com/mayank013p/ivors"

  preflight do
    # Kill running instance if present (must_succeed: false prevents error if not running)
    system_command "/usr/bin/pkill", args: ["-f", "Ivors.app"], sudo: false, must_succeed: false
    # Remove existing /Applications/Ivors.app if present to prevent collision errors
    target_app = "#{appdir}/Ivors.app"
    FileUtils.rm_rf(target_app) if File.exist?(target_app)
  end

  app "Ivors.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Ivors.app"],
                   sudo: false
  end

  uninstall quit: "com.mayank.ivors"

  zap trash: [
    "~/Library/Preferences/com.mayank.ivors.plist",
    "~/Library/Application Support/Ivors",
    "~/Library/Saved Application State/com.mayank.ivors.savedState",
  ]
end
