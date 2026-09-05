cask "ivors" do
  version "1.4.0"
  sha256 "e3bcd2c85f2073dc426dcc673e7bd4bfae480cd74dcee7f1582f49a1d11c093d"

  url "https://raw.githubusercontent.com/mayank013p/ivors/main/Ivors-macOS.zip"
  name "Ivors"
  desc "Dynamic Island & Notch Productivity HUD for macOS"
  homepage "https://github.com/mayank013p/ivors"

  preflight do
    # Kill any running instance before installing
    system_command "/usr/bin/killall", args: ["Ivors"], sudo: false, print_stderr: false
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

  uninstall quit: "com.mayank.ivors",
            delete: "#{appdir}/Ivors.app"

  zap trash: [
    "~/Library/Preferences/com.mayank.ivors.plist",
    "~/Library/Application Support/Ivors",
    "~/Library/Saved Application State/com.mayank.ivors.savedState",
  ]
end
