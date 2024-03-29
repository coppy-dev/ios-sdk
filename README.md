# Coppy iOS SDK

Coppy SDK for iOS consists of two major parts:

1. CLI tool, which is responsible for generating Swift classes that will be used by the app in the runtime. These classes also provide IDE autocompletion and better dev experience.
2. The runtime module, which is responsible for downloading new versions of content and updating the copy in the app.

## Prerequisities

1. **Swift UI framework**. At the moment, Coppy only works with projects that are built with the Swift UI framework. Swift UI provides us with all necessary abstractions that allow us to efficiently update app copy in the runtime.

2. **Coppy content key**. The content key tells the Coppy plugin and runtime SDK how to get your specific content. To get a content key, go to your [Coppy profile page](https://app.coppy.app/profile) and select a specific team, which content you want to use in the app. The content key will be right below the team name.
<picture width="1280" role="presentation">
    <source media="(prefers-color-scheme: dark)" srcset="https://coppy.app/images/docs/content-key-dark.png" />
    <source media="(prefers-color-scheme: light)" srcset="https://coppy.app/images/docs/content-key.png" />
    <img src="https://coppy.app/images/docs/content-key.png" />
</picture>

## Getting started

### 1. Install the [Coppy CLI tool](https://github.com/coppy-dev/ios-cli)

There are a few ways to install the CLI tool:

- **by using our install script**, which will download the CLI, unzip it into `.coppy` directory in your user's home directory, and add it to your terminal config file (bash, zsh, etc.) so it can be correctly called by `coppy` in your terminal. To use this script, just run the below command in your terminal:

  ```bash
  curl -fsSL https://coppy.app/ios/install.sh | bash
  ```

  The downside of this approach is that, although we update your shell config to use the Coppy CLI binary, the other apps (like Xcode) don't use this config, and thus you might get an error that the `coppy` command is not found. To fix this behavior, you will need to call Coppy CLI tool by the full path name (i.e., `/Users/<your user name/.coppy/bin/coppy`).

- **by using our [install package](https://github.com/coppy-dev/ios-cli/releases/latest/download/coppy.pkg)**. The package will install Coppy CLI into `usr/local/bin` directory, where it will become available to all tools and apps in the system. So you will be able to use it in Xcode or other apps just by calling `coppy` command. However, we will ask for your user's password during the installation to be able to save the Coppy CLI binary into the right directory.

- **by downloading and unzipping the archive with [the latest release](https://github.com/coppy-dev/ios-cli/releases/latest/download/coppy.zip)**. After that, it is up to you to save the binary into a specific folder and configure our environment to use it. 

### 2. Add Coppy config plist

Next, you need to add a `Coppy.plist` file into your target's directory. Add a `ContentKey` field with your content key.

```diff
+<?xml version="1.0" encoding="UTF-8"?>
+<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
+<plist version="1.0">
+    <dict>
+    	<key>ContentKey</key>
+    	<string>iJHm-bZfcTZ98yNJ_Gkw1</string>
+    </dict>
+</plist>
```
<picture width="1280" role="presentation">
    <source media="(prefers-color-scheme: dark)" srcset="https://coppy.app/images/docs/coppy-plist-dark.png" />
    <source media="(prefers-color-scheme: light)" srcset="https://coppy.app/images/docs/coppy-plist.png" />
    <img src="https://coppy.app/images/docs/coppy-plist.png" />
</picture>

### 3. Add script phase to the build process
You need to add a custom build script phase into your build process, so Coppy CLI could generate runtime classes that will be used by the app.
In Xcode, open `Build Phases` of your target settings, and a add a new `Run Script` phase.

Then add a bash script, that calls the Coppy CLI tool, and generates content:
```bash
coppy generate "$SRCROOT/$TARGET_NAME/Coppy.plist" "$SRCROOT/$TARGET_NAME/generated/Coppy.swift"
```
<picture width="1280" role="presentation">
    <source media="(prefers-color-scheme: dark)" srcset="https://coppy.app/images/docs/script-dark.png" />
    <source media="(prefers-color-scheme: light)" srcset="https://coppy.app/images/docs/script.png" />
    <img src="https://coppy.app/images/docs/script.png" />
</picture>

Optionally, you can add a class name prefix, if you want the generated classes to have more specific names. To do that, pass the third argument to the Coppy CLI. Target name might be a good option:
```bash
coppy generate "$SRCROOT/$TARGET_NAME/Coppy.plist" "$SRCROOT/$TARGET_NAME/generated/Coppy.swift" $TARGET_NAME
```

Make sure you turn off the user script sandboxing in your target build settings. Otherwise, you might get errors that the Coppy CLI does not have permission to read the config file (`Coppy.plist`).

<picture width="1280" role="presentation">
    <source media="(prefers-color-scheme: dark)" srcset="https://coppy.app/images/docs/sandbox-dark.png" />
    <source media="(prefers-color-scheme: light)" srcset="https://coppy.app/images/docs/sandbox.png" />
    <img src="https://coppy.app/images/docs/sandbox.png" />
</picture>

### 4. Add generated classes to the project
After you've added a coppy generation phase to your build process, run a build command and let the Coppy CLI generate runtime classes. Then, add the generated file to the project, so the Xcode can index its content and provide you with code completion and type checking.

### 5. Add Coppy SDK to your project

Add Coppy SDK using link to [this same repository](https://github.com/coppy-dev/ios-sdk.git)

### 6. Add coppy to your app code

To use coppy in your app, you need to first initialize it in your `App` class and att it to your views hierarchy

```diff
import SwiftUI
+import Coppy

@main
struct LemiApp: App {
+   init() {
+       Coppy.initialize(CoppyContent.self)
+   }
    var body: some Scene {
        WindowGroup {
-           ContentView()
+           ContentView().environmentObject(Coppy.content(LemiCoppyContent.self))
        }
    }

}
```

Then, you can use coppy content in your components:

```diff
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var content: LemiCoppyContent
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Card(
-                   title: "Cover+",
-                   text: "Overdraft with no fees! Your Cover+ base starts at $60 and can reach $400 over time",
-                   cta: "Get Cover+
+                   title: content.features.coverMe.cta.title,
+                   text: content.features.coverMe.cta.body,
+                   cta: content.features.coverMe.cta.cta
                )
            }
            .padding()
        }
        
    }
}
```

Now, the Coppy SDK will check for content updates when the app is going to the background. Once you publish a newer version of your content, Coppy SDK will download it and apply the changes to your app screens. 

## Ejecting

If you no longer want to use Coppy and pay for it, you can still leave its SDK in your project. You don't need to make a huge app refactoring and replace all cases of using Coppy with the hard-coded copy. Your copy will stay in the app for as long as needed.
