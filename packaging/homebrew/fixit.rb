# Cask template for the ivanrvpereira/homebrew-tap repository.
# The release workflow fills in the version and sha256 placeholders, attaches
# the rendered fixit.rb to each GitHub release, and pushes it to Casks/fixit.rb
# in the tap (copy it manually only if TAP_PUSH_TOKEN is unset).
cask "fixit" do
  version "{{VERSION}}"
  sha256 "{{SHA256}}"

  url "https://github.com/ivanrvpereira/fixit/releases/download/v#{version}/Fixit-#{version}.zip"
  name "Fixit"
  desc "Fix typos and polish phrasing in any app with one hotkey"
  homepage "https://github.com/ivanrvpereira/fixit"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Fixit.app"

  # The app is signed in CI with a stable release identity, so the
  # Accessibility (TCC) grant survives upgrades without local re-signing.
  # It is not notarized, so strip quarantine to keep Gatekeeper from
  # blocking it. Nothing touches the user's keychain.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Fixit.app"]
  end

  caveats <<~EOS
    If macOS asks for Accessibility permission again after upgrading from a
    locally re-signed version, re-grant it once in System Settings >
    Privacy & Security > Accessibility.
  EOS

  zap trash: "~/.config/fixit"
end
