# Coppy iOS SDK

Coppy SDK for iOS consists of two major parts:

1. CLI tool, which is responsible for generating Swift classes that will be used by the app in the runtime. These classes also provide IDE autocompletion and better dev experience.
2. The runtime module, which is responsible for downloading new versions of content and updating the copy in the app.

## Prerequisities

1. **Swift UI framework**. At the moment, Coppy only works with projects that are built with the Swift UI framework. Swift UI provides us with all necessary abstractions that allow us to efficiently update app copy in the runtime.

2. **Coppy content key**. The content key tells the Coppy plugin and runtime SDK how to get your specific content. To get a content key, go to your [Coppy profile page](https://app.coppy.app/profile) and select a specific team, which content you want to use in the app. The content key will be right below the team name.
<img src="https://github.com/coppy-dev/ios-sdk/assets/112951687/48cccfe0-2e15-4910-876e-50acbd3794f7" width="1280" role="presentation" />


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
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/coppy-dev/ios-sdk/assets/112951687/1cf42bcd-44d4-4286-8004-e914b0ef7c36" />
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/coppy-dev/ios-sdk/assets/112951687/930c1470-6830-41b8-a801-4a30f4486e66" />
    <img src="https://github.com/coppy-dev/ios-sdk/assets/112951687/930c1470-6830-41b8-a801-4a30f4486e66" />
</picture>

### 3. Add script phase to the build process
You need to add a custom build script phase into your build process, so Coppy CLI could generate runtime classes that will be used by the app.
In Xcode, open `Build Phases` of your target settings, and a add a new `Run Script` phase.

Then add a bash script, that calls the Coppy CLI tool, and generates content:
```bash
coppy generate "$SRCROOT/$TARGET_NAME/Coppy.plist" "$SRCROOT/$TARGET_NAME/generated/Coppy.swift"
```
<picture width="1280" role="presentation">
    <source media="(prefers-color-scheme: dark)" srcset="[https://github.com/coppy-dev/ios-sdk/assets/112951687/1cf42bcd-44d4-4286-8004-e914b0ef7c36](https://github.com/coppy-dev/ios-sdk/assets/112951687/b5d2187f-aa56-495e-8365-4a4f6a869c2e)" />
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/coppy-dev/ios-sdk/assets/112951687/d234d758-0454-4735-88d4-ca2da49a65d8" />
    <img  src="https://github.com/coppy-dev/ios-sdk/assets/112951687/d234d758-0454-4735-88d4-ca2da49a65d8" />
</picture>

Optionally, you can add a class name prefix, if you want the generated classes to have more specific names. To do that, pass the third argument to the Coppy CLI. Target name might be a good option:
```bash
coppy generate "$SRCROOT/$TARGET_NAME/Coppy.plist" "$SRCROOT/$TARGET_NAME/generated/Coppy.swift" $TARGET_NAME
```

Make sure you turned off the user script sandboxing in your target build settings. Otherwise, you might get errors, that the Coppy CLI does not have permissions to read config file (`Coppy.plist`).


### Using copy at runtime

To use coppy in your app, you need to first initialize it in your main activity:

```diff
+import app.coppy.Coppy
+import app.coppy.generatedCoppy.CoppyContent

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

+       Coppy.initialize(applicationContext, CoppyContent::class.java)

        setContent {
            App()
        }
    }
}
```

Then, you can use coppy content in your component:

```diff
+import app.coppy.Coppy
+import app.coppy.generatedCoppy.CoppyContent

@Preview(showBackground = true)
@Composable
fun IntroScreen (
    onClick: () -> Unit = {}
) {
+    val intro = Coppy.useContent(CoppyContent::class.java).collectAsState().value.features.intro
    Column(
        Modifier
            .fillMaxWidth(1f)
            .fillMaxHeight(1f), verticalArrangement = Arrangement.SpaceBetween) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
-            Text(text = "Welcome Back!", fontSize = 30.sp)
+            Text(text = intro.title, fontSize = 30.sp)
-            Text(text = "Happy to see you again! Here are some things you've might missed", fontSize = 16.sp)
+            Text(text = intro.body, fontSize = 16.sp)

        }
        Column(Modifier.padding(16.dp, 12.dp)) {
            Button(onClick = onClick, modifier = Modifier
                .fillMaxWidth()
                .height(44.dp)) {
-                Text(text = "Get Started")
+                Text(text = intro.cta)
            }
        }
    }
}
```

## Configuration

At the moment, there are a few things you can configure in how Coppy SDK works:

1. **Update interval (`updateInterval`)** — interval in minutes for how often Coppy SDK should check for the new content version. By default, it is 30 minutes.t

2. **Update type (`updateType`)** — defines how Coppy will update the app copy in the runtime. Note that it will still check for copy updates within specified intervals (`updateInterval`). But, depending on the update type setting, it might not apply those changes immediately. Instead, it will store them locally and will use them for the next copy update. By default (if option is not set), Coppy will check only update copy when app is hard-reloaded (i.e user closes the app, and opens it again).
   - `background` — Coppy will update the copy when the app is backgrounded. Note that because Compose UI does not run in the background, the actual copy update will happen when the app comes back from the background into the foreground.
   - `foreground` — Coppy will update the copy in the app as soon as it gets the new version of content from the server.

```diff
plugins {
    id("com.android.application")
    id("app.coppy") version("1.0.0")
}

coppy {
    contentKey = "<YOUR_CONTENT_KEY>"
+    updateInterval = 15
+    updateType = "foreground"
}
```

## Ejecting

If you no longer want to use Coppy and pay for it, you can still leave its SDK in your project. You don't need to make a huge app refactoring and replace all cases of using Coppy with the hard-coded copy. Your copy will stay in the app for as long as needed.
