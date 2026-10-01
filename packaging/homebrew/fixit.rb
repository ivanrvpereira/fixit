# Cask template for the ivanrvpereira/homebrew-tap repository.
# The release workflow fills in the version and sha256 placeholders, packages
# the notarized app, attaches this rendered cask to each GitHub release, and
# pushes it to Casks/fixit.rb in the tap.
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

  auto_updates true
  depends_on macos: :ventura

  app "Fixit.app"

  zap trash: "~/.config/fixit"

  caveats <<~EOS
    Upgrading from a pre-notarized (self-signed) version changes the signing
    identity, so macOS will ask once to re-grant Accessibility in System
    Settings > Privacy & Security > Accessibility.
  EOS
end
