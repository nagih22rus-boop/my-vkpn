import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  private func listMacInstalledApps() -> [[String: String]] {
    var pairs: [(String, String)] = []
    var seen = Set<String>()
    let bases = ["/Applications", "/System/Applications", "\(NSHomeDirectory())/Applications"]
    let fm = FileManager.default
    for base in bases {
      guard let urls = try? fm.contentsOfDirectory(
        at: URL(fileURLWithPath: base),
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      ) else {
        continue
      }
      for url in urls where url.pathExtension == "app" {
        guard let bundle = Bundle(url: url) else { continue }
        let bid = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        if !seen.insert(bid).inserted { continue }
        let name =
          (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
          ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
          ?? (bundle.infoDictionary?["CFBundleName"] as? String)
          ?? url.deletingPathExtension().lastPathComponent
        pairs.append((bid, name))
      }
    }
    pairs.sort {
      $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending
    }
    return pairs.map { ["id": $0.0, "label": $0.1] }
  }
}
