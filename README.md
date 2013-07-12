# Centauri
A flexible log capture and session analytics service for iOS.

Centauri consists of two components: a client side library (this project) and a web application. The library collects and transmits session and log data to the web application, where you can later review usage data and examine logs to help debug problems.

This client library requires iOS 5.0 or later. You also need an account to use the web application. Visit [https://centauriapp.com/](https://centauriapp.com/) to get started.

## Features
* Log user sessions to a central service for later review while debugging.
* More flexible logging than plain `NSLog`: specify a severity level and use tags to categorize log messages. Logs can be filtered on the web to focus on only those that matter to the issue you are investigating.
* Easy on the network: sessions and logs are buffered and sent in batches. The library is resilient to transient network failures and data will be sent later.
* The integration library is open source: see exactly what code you're including in your app.

## Integration
1. Drag `Centauri.xcodeproj` into your app's project.
2. In Xcode, click on your project in the Project Navigator.
3. In the Build Phases for the target(s) you want to add Centauri to, expand Link Binary With Libraries, click the "+" to add a new library and choose `libCentauri.a`. It should be at the top of the list, under "Workspace".
4. In the Build Settings for either the whole project or individual targets, add the "Centauri" folder to Header Search Paths.
5. Add `#import "Centauri.h"` to either your prefix header (usually in the Supporting Files group) or to the top of each file where you want to use Centauri.
6. In your app delegate, call `[[Centauri sharedInstance] beginSession:@"YOUR-APP-TOKEN"]` near the top of `application:didFinishLaunchingWithOptions:`.
7. Optionally, also call `[[Centauri sharedInstance] beginLogging]` if you want to capture log statements. You should probably condition this for apps submitted to the App Store; see the website for ideas on how you can selectively enable logging only for certain users.

## Replacing `NSLog`
The simplest way to try Centauri out is to define a macro that substitutes calls to `NSLog` with calls to Centauri's logger:

    #define NSLog CENLog

You could also use the current source file as a tag:

    #define NSLog(...) CENLogT(@__FILE__, __VA_ARGS__)

## Contributing
1. Fork the project.
2. Create a feature or bug fix branch.
3. Add a Kiwi spec that covers your change(s). (You need to initialize the submodules to run the specs: `git submodule --init --recursive`.)
4. Commit your changes.
5. Push your branch.
6. Create a pull request.
